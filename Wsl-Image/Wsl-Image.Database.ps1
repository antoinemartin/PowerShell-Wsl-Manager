using namespace System.IO;
using namespace System.Timers;
using namespace System.Data;

# cSpell: ignore Linq

[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
$DatabaseDatadir = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path -Path "$HOME" -ChildPath ".local/share" }
$BaseImageDatabaseFilename = [FileInfo]::new(@($DatabaseDatadir, "Wsl", "RootFS", "images.db") -join [Path]::DirectorySeparatorChar)
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$BaseDatabaseStructure = (Get-Content (Join-Path $PSScriptRoot "db.sqlite") -Raw)


function Build-WslImage-MissingMetadata {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseSingularNouns', '')]
    [CmdletBinding()]
    param(
        [DirectoryInfo] $BasePath = $null
    )
    if ($null -eq $BasePath) {
        $BasePath = [WslImage]::BasePath
    }
    if (-not $BasePath.Exists) {
        Write-Verbose "Base path $($BasePath.FullName) does not exist. Nothing to transfer."
        return
    }
    # First get tar.gz files and json files
    $tarFiles = $BasePath.GetFiles("*.rootfs.tar.gz", [SearchOption]::TopDirectoryOnly)
    $jsonFiles = $BasePath.GetFiles("*.rootfs.tar.gz.json", [SearchOption]::TopDirectoryOnly)
    $tarBaseNames = $tarFiles | ForEach-Object { $_.Name -replace '\.rootfs\.tar\.gz$', '' }
    $jsonBaseNames = $jsonFiles | ForEach-Object { $_.Name -replace '\.rootfs\.tar\.gz\.json$', '' }
    if ($tarBaseNames -and $jsonFiles) {
        [System.Linq.Enumerable]::Except([object[]]$tarBaseNames, [object[]]$jsonBaseNames) | ForEach-Object {
            Write-Verbose "No matching JSON file for tarball $_.rootfs.tar.gz. Creating metadata."
            # TODO: As WslImage is going to be refactored, the code getting metadata should be moved
            $null = [WslImage]::new([FileInfo]::new((Join-Path -Path $BasePath.FullName -ChildPath "$_.rootfs.tar.gz")))
        }
    }
}


function Move-LocalWslImage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [ValidateNotNull()]
        [SQLiteHelper] $Database,
        [DirectoryInfo] $BasePath = $null,
        [switch] $DoNotChangeFiles
    )

    if (-not $Database.IsOpen) {
        throw [WslManagerException]::new("The image database is not open.")
    }
    if ($null -eq $BasePath) {
        $BasePath = [WslImage]::BasePath
    }
    if (-not $BasePath.Exists) {
        Write-Verbose "Base path $($BasePath.FullName) does not exist. Nothing to transfer."
        return
    }
    # Build missing metadata for local images
    Build-WslImage-MissingMetadata -BasePath $BasePath
    Get-WslBuiltinImage -Type Builtin | Out-Null
    Get-WslBuiltinImage -Type Incus | Out-Null
    # Now we can loop through JSON files
    $jsonFiles = $BasePath.GetFiles("*.json", [SearchOption]::TopDirectoryOnly)
    Write-Verbose "Found $($jsonFiles.Count) JSON files. Processing..."
    $query = $Database.CreateUpsertQuery("LocalImage")
    $querySource = $Database.CreateUpsertQuery("ImageSource", @('Id'))
    $jsonFiles | ForEach-Object {
        Write-Verbose "Processing file $($_.FullName)..."
        $image = Get-Content -Path $_.FullName | ConvertFrom-Json | Convert-PSObjectToHashtable
        # fix Uid
        if ($image.ContainsKey('Uid') -and $image.ContainsKey('Username') -and $image.Uid -eq 0 -and $image.Username -ne 'root') {
            $image.Uid = 1000
        }
        $hash = if ($image.Hash) { $image.Hash } else { $image.HashSource }
        if (-not $image.Name) {
            Write-Verbose "No name found in JSON file. Trying to get information from filename $($_.BaseName)..."
            $fileNameInfo = Get-DistributionInformationFromName -Name $_.BaseName
            foreach ($key in $fileNameInfo.Keys) {
                $image[$key] = $fileNameInfo[$key]
            }
        }
        # Try to find the source
        $ImageSourceId = $null
        $LocalImageId = [Guid]::NewGuid().ToString()
        if ($image.Type -in [WslImageType]::Builtin, [WslImageType]::Incus) {
            Write-Verbose "Looking for existing image source $($image.Type)/$($image.Os)/$($image.Release)/$($image.Configured)..."
            $dt = $Database.ExecuteSingleQuery("SELECT * FROM ImageSource WHERE Type = @Type AND Distribution = @Distribution AND Release = @Release AND Configured = @Configured;",
                @{
                    Type = $image.Type.ToString()
                    Distribution = $image.Os
                    Release = $image.Release
                    Configured = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
                })
            if ($null -ne $dt -and $dt.Rows.Count -gt 0) {
                $ImageSourceId = $dt.Rows[0].Id
                Write-Verbose "Found existing image source with ID $($ImageSourceId)."
            }
        } elseif ($image.Type -eq [WslImageType]::Uri) {
            Write-Verbose "Looking for existing image source on Uri $($image.Url)..."
            [System.Uri] $uri = $image.Url
            if ($uri.IsAbsoluteUri -and ($uri.Scheme -eq 'docker')) {
                Write-Verbose "Docker image detected. Converting to Docker type."
                $image.Type = [WslImageType]::Docker
            }
            $dt = $Database.ExecuteSingleQuery("SELECT * FROM ImageSource WHERE Type = @Type AND Url = @Url;",
                @{
                    Type = $image.Type.ToString()
                    Url = $image.Url
                })
            if ($null -ne $dt -and $dt.Rows.Count -gt 0) {
                $ImageSourceId = $dt.Rows[0].Id
                Write-Verbose "Found existing image source with ID $($ImageSourceId)."
            }
        } else {
            Write-Verbose "Looking for existing image source on Digest $($image.FileHash)..."
            $dt = $Database.ExecuteSingleQuery("SELECT * FROM ImageSource WHERE Digest = @Digest;",
                @{
                    Digest = $image.FileHash
                })
            if ($null -ne $dt -and $dt.Rows.Count -gt 0) {
                $ImageSourceId = $dt.Rows[0].Id
                Write-Verbose "Found existing image source with ID $($ImageSourceId)."
            }
        }
        if (-not $ImageSourceId) {
            Write-Verbose "No existing image source found. Creating a new one."
            $ImageSourceId = [Guid]::NewGuid().ToString()
            $parametersSource = @{
                Id = $ImageSourceId
                Name = $image.Name
                Tags = if ($image.Tags) { $image.Tags -join ',' } else { $image.Release }
                Url = $image.Url
                Type = ($image.Type -as [WslImageType]).ToString()
                Configured = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
                Username = if ($image.ContainsKey('Username')) { $image.Username } elseif ($image.Configured) { $image.Os } else { 'root' }
                Uid = if ($image.ContainsKey('Uid')) { $image.Uid } elseif ($image.Configured) { 1000 } else { 0 }
                Distribution = $image.Os
                Release = $image.Release
                LocalFilename = $image.LocalFilename
                DigestSource = $hash.Type
                DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
                DigestUrl = $hash.Url
                Digest = $image.FileHash
                GroupTag = $LocalImageId
            }
            Write-Verbose "Inserting new image source with parameters:`n$($parametersSource | ConvertTo-Json -Depth 5)..."
            if ($PSCmdlet.ShouldProcess("ImageSource", "Insert new image source $($image.Name)")) {
                $resultSource = $Database.ExecuteNonQuery($querySource, $parametersSource)
                if (0 -ne $resultSource) {
                    throw [WslManagerException]::new("Failed to insert or update image source for local image $($image.Name) into the database. result: $resultSource")
                }
                $ImageSourceId = $parametersSource.Id
                Write-Verbose "Created new image source with ID $($ImageSourceId)."
            }
        }

        $newFileName = if ($hash.Algorithm -eq "SHA256") { "$($image.FileHash).rootfs.tar.gz" } else { "$($hash.Algorithm)_$($image.FileHash).rootfs.tar.gz" }
        $imageFile = Join-Path -Path $BasePath.FullName -ChildPath $_.BaseName
        $localFileExists = Test-Path -Path $imageFile
        $parameters = @{
            Id = $LocalImageId
            ImageSourceId = $ImageSourceId
            # CreationDate = $null
            # UpdateDate = $null
            Name = $image.Name
            Tags = if ($image.Tags) { $image.Tags -join ',' } else { $image.Release }
            Url = $image.Url
            Type = ($image.Type -as [WslImageType]).ToString()
            Configured = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
            Username = if ($image.ContainsKey('Username')) { $image.Username } elseif ($image.Configured) { $image.Os } else { 'root' }
            Uid = if ($image.ContainsKey('Uid')) { $image.Uid } elseif ($image.Configured) { 1000 } else { 0 }
            Distribution = $image.Os
            Release = $image.Release
            LocalFilename = $newFileName
            DigestSource = $hash.Type
            DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
            DigestUrl = $hash.Url
            Digest = $image.FileHash
            State  = if ($localFileExists) { 'Synced' } else { 'NotDownloaded' }
        }
        Write-Verbose "Inserting or updating local image $($image.Name) into the database with parameters:`n$($parameters | ConvertTo-Json -Depth 5)..."
        if ($PSCmdlet.ShouldProcess("LocalImage", "Insert or update local image $($image.Name)")) {
            $result = $Database.ExecuteNonQuery($query, $parameters)
            if (0 -ne $result) {
                throw [WslManagerException]::new("Failed to insert or update local image $($image.Name) into the database. result: $result")
            }
            Write-Verbose "Inserted or updated local image $($image.Name) into the database."
        }

        if (Test-Path -Path $imageFile) {
            if ($PSCmdlet.ShouldProcess("File", "Rename image file $imageFile to $newFileName")) {
                $newFile = Join-Path -Path $BasePath.FullName -ChildPath $newFileName
                if (-not (Test-Path -Path $newFile)) {
                    Write-Verbose "Renaming image file from $imageFile to $newFileName."
                    if ($DoNotChangeFiles) {
                        Write-Verbose "DoNotChangeFiles is set. Skipping file operation."
                    } else {
                        Rename-Item -Path $imageFile -NewName $newFileName -Force
                    }
                } else {
                    Write-Verbose "Target file $newFile already exists. Deleting source file $imageFile."
                    if ($DoNotChangeFiles) {
                        Write-Verbose "DoNotChangeFiles is set. Skipping file operation."
                    } else {
                        Remove-Item -Path $imageFile -Force | Out-Null
                    }
                }
            }
        } else {
            Write-Verbose "Image file $imageFile does not exist. Nothing to rename."
        }

        if ($PSCmdlet.ShouldProcess("File", "Remove JSON file $($_.FullName)")) {
            Write-Verbose "Finished processing file $($_.FullName). Removing JSON file."
            if ($DoNotChangeFiles) {
                Write-Verbose "DoNotChangeFiles is set. Skipping file operation."
            } else {
                Remove-Item -Path $_.FullName -Force | Out-Null
            }
        }
    }
}



class WslImageDatabase {

    WslImageDatabase() {
        # Create the database directory (with parents) if it doesn't exist
        [WslImageDatabase]::DatabaseFileName.Directory.Create() | Out-Null
    }

    [bool] IsOpen() {
        return $null -ne $this.db
    }

    [void] Open() {
        if ($this.IsOpen()) {
            throw [WslManagerException]::new("The image database is already open.")
        }

        # Create the database if it doesn't exist
        Write-Verbose "Opening database file: $([WslImageDatabase]::DatabaseFileName.FullName)"
        $this.db = [SQLiteHelper]::open([WslImageDatabase]::DatabaseFileName.FullName)
        $this.db.UpdateTimestampColumn = 'UpdateDate'
        Write-Verbose "Database opened."

        # Get the current version from the database
        $rs = $this.db.ExecuteSingleQuery("PRAGMA user_version;")
        $this.version = if ($rs.Item.Count -gt 0) { $rs[0].user_version } else { 0 }
        Write-Verbose "Database version: $($this.version)"
    }

    [void] Close() {
        if ($this.IsOpen()) {
            $this.db.Close()
            $this.db = $null
            $this.version = 0
        }
    }

    [bool] IsUpdatePending() {
        return $this.version -lt [WslImageDatabase]::CurrentVersion
    }

    [PSCustomObject] GetImageSourceCache([WslImageType]$Type) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        $dt = $this.db.ExecuteSingleQuery("SELECT * FROM ImageSourceCache WHERE Type = @Type;", @{ Type = $Type.ToString() })
        return $dt | ForEach-Object {
            [PSCustomObject]@{
                Type      = $_.Type
                Url       = $_.Url
                LastUpdate = $_.LastUpdate
                Etag      = $_.Etag
            }
        }
    }

    [void] UpdateImageSourceCache([WslImageType]$Type, [PSCustomObject]$CacheData) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        $query = $this.db.CreateUpsertQuery("ImageSourceCache")
        $parameters = @{
            Type       = $Type.ToString()
            Url        = $CacheData.Url
            LastUpdate = $CacheData.LastUpdate
            Etag       = $CacheData.Etag
        }
        $null = $this.db.ExecuteNonQuery($query, $parameters)
    }

    [PSCustomObject[]] GetImageBuiltins([WslImageType]$Type) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        $dt = $this.db.ExecuteSingleQuery("SELECT * FROM ImageSource WHERE Type = @Type;", @{ Type = $Type.ToString() })
        return $dt | ForEach-Object {
            [PSCustomObject]@{
                Id              = $_.Id
                Name            = $_.Name
                Url             = $_.Url
                Type            = $_.Type -as [WslImageType]
                Tags            = if ($_.Tags) { $_.Tags -split ',' } else { @() }
                Configured      = if ('TRUE' -eq $_.Configured) { $true } else { $false }
                Username        = $_.Username
                Uid             = $_.Uid
                Os              = $_.Distribution
                Release         = $_.Release
                LocalFilename   = $_.LocalFilename
                HashSource      = [PSCustomObject]@{
                    Type        = $_.DigestSource
                    Algorithm   = $_.DigestAlgorithm
                    Mandatory   = $true
                    Url         = if ([System.DBNull]::Value.Equals($_.DigestUrl)) { $null } else { $_.DigestUrl }
                }
                Digest          = if ([System.DBNull]::Value.Equals($_.Digest)) { $null } else { $_.Digest }
            }
        }
    }

    [void] SaveImageBuiltins([WslImageType]$Type, [PSCustomObject[]]$Images, [string]$GroupTag = $null) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        $query = $this.db.CreateUpsertQuery("ImageSource", @('Id'))
        foreach ($image in $Images) {
            $hash = if ($image.Hash) { $image.Hash } else { $image.HashSource }
            $parameters = @{
                Id            = [Guid]::NewGuid().ToString()
                Name          = $image.Name
                Tags          = $image.Tags -join ','
                Url           = $image.Url
                Type          = $image.Type.ToString()
                Configured    = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
                Username      = $image.Username
                Uid           = $image.Uid
                Distribution  = $image.Os
                Release       = $image.Release
                LocalFilename = $image.LocalFilename
                DigestSource  = $hash.Type
                DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
                Digest        = if ($image.FileHash) { $image.FileHash } elseif ($image.Digest) { $image.Digest } else { $null }
                DigestUrl     = $hash.Url
                GroupTag      = $GroupTag
            }
            if (0 -ne $this.db.ExecuteNonQuery($query, $parameters)) {
                throw [WslManagerException]::new("Failed to insert or update image $($image.Name) into the database.")
            }
        }
        Write-Verbose "Saved $($Images.Count) images of type $Type into the database with group tag $GroupTag. Removing old images..."
        $result = $this.db.ExecuteNonQuery("DELETE FROM ImageSource WHERE Type = @Type AND GroupTag IS NOT @GroupTag;", @{ Type = $Type.ToString(); GroupTag = $GroupTag })
        if (0 -ne $result) {
            throw [WslManagerException]::new("Failed to remove old images of type $Type from the database. result: $result")
        }

        # Update local images state
        Write-Verbose "Updating local images state based on new image sources..."
        $result = $this.db.ExecuteNonQuery("UPDATE LocalImage SET State = 'Outdated' FROM ImageSource WHERE LocalImage.ImageSourceId = ImageSource.Id AND LocalImage.Digest <> ImageSource.Digest;")
        if (0 -ne $result) {
            throw [WslManagerException]::new("Failed to update local images state. result: $result")
        }
    }

    [PSCustomObject[]] GetLocalImages() {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        $dt = $this.db.ExecuteSingleQuery("SELECT * FROM LocalImage;")
        return $dt | ForEach-Object {
            [PSCustomObject]@{
                Id              = $_.Id
                ImageSourceId   = $_.ImageSourceId
                Name            = $_.Name
                Url             = $_.Url
                Type            = $_.Type -as [WslImageType]
                Tags            = if ($_.Tags) { $_.Tags -split ',' } else { @() }
                Configured      = if ('TRUE' -eq $_.Configured) { $true } else { $false }
                Username        = $_.Username
                Uid             = $_.Uid
                Os              = $_.Distribution
                Release         = $_.Release
                LocalFilename   = $_.LocalFilename
                HashSource      = [PSCustomObject]@{
                    Type        = $_.DigestSource
                    Algorithm   = $_.DigestAlgorithm
                    Mandatory   = $true
                    Url         = if ([System.DBNull]::Value.Equals($_.DigestUrl)) { $null } else { $_.DigestUrl }
                }
                FileHash       = if ([System.DBNull]::Value.Equals($_.Digest)) { $null } else { $_.Digest }
                State          = $_.State
            }
        }
    }


    [void] CreateDatabaseStructure() {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }

        # Create the necessary tables and indexes
        $null = $this.db.ExecuteNonQuery([WslImageDatabase]::DatabaseStructure)
    }

    [void] TransferBuiltinImages([WslImageType]$Type = [WslImageType]::Builtin) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        Write-Verbose "Transferring built-in images from source $Type..."
        $Uri = [System.Uri]([WslImageDatabase]::WslImageSources[$Type])
        $CacheFilename = $Uri.Segments[-1]
        $cacheFile = Join-Path -Path ([WslImage]::BasePath) -ChildPath $CacheFilename
        if (-not (Test-Path -Path $cacheFile)) {
            Write-Verbose "Cache file $cacheFile does not exist."
            return
        }
        Write-Verbose "Loading cache from file $cacheFile"
        $cache = Get-Content -Path $cacheFile | ConvertFrom-Json

        # First insert the cache information
        Write-Verbose "Inserting cache information into ImageSourceCache..."
        $query = $this.db.CreateUpsertQuery("ImageSourceCache")
        $parameters = @{
            Type = $Type.ToString()
            Url = $cache.Url
            LastUpdate = $cache.lastUpdate
            Etag = $cache.etag
        }
        $null = $this.db.ExecuteNonQuery($query, $parameters)

        # Next insert the cache information into ImageSource
        Write-Verbose "Inserting cache information into ImageSource..."
        $query = $this.db.CreateUpsertQuery("ImageSource")
        Write-Verbose "query: $query"
        foreach ($image in $cache.builtins) {
            $hash = if ($image.Hash) { $image.Hash } else { $image.HashSource }
            $parameters = @{
                Id = [Guid]::NewGuid().ToString()
                # CreationDate = $null
                # UpdateDate = $null
                Name = $image.Name
                Tags = if ($image.Tags) { $image.Tags -join ',' } else { $image.Release }
                Url = $image.Url
                Type = ($image.Type -as [WslImageType]).ToString()
                Configured = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
                Username = $image.Username
                Uid = $image.Uid
                Distribution = $image.Os
                Release = $image.Release
                LocalFilename = $image.LocalFilename
                DigestSource = $hash.Type
                DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
                DigestUrl = $hash.Url
                Digest = $null
            }
            $result = $this.db.ExecuteNonQuery($query, $parameters)
            if (0 -ne $result) {
                throw [WslManagerException]::new("Failed to insert or update image $($image.Name) into the database. result: $result")
            }
        }

        # Delete the source file
        Remove-Item -Path $cacheFile -Force | Out-Null
    }

    [void] AddImageSourceGroupTag() {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        Write-Verbose "Adding GroupTag column to ImageSource table..."
        $result = $this.db.ExecuteNonQuery([WslImageDatabase]::AddImageSourceGroupTagSql)
        if (0 -ne $result) {
            throw [WslManagerException]::new("Failed to add GroupTag column to ImageSource table. result: $result")
        }
    }

    [void] TransferLocalImages([DirectoryInfo] $BasePath = $null) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        if ($null -eq $BasePath) {
            $BasePath = [WslImage]::BasePath
        }
        Move-LocalWslImage -Database $this.db -BasePath $BasePath
    }

    [void]UpdateVersion([int]$NewVersion) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        if ($NewVersion -le $this.version) {
            throw [WslManagerException]::new("The new version $NewVersion must be greater than the current version $($this.version).")
        }
        $null = $this.db.ExecuteNonQuery("PRAGMA user_version = $NewVersion;VACUUM;")
        $this.version = $NewVersion
    }

    [void] UpdateIfNeeded([int]$ExpectedVersion) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }

        Write-Verbose "Updating image database from version $($this.version)..."

        if ($this.version -lt 1 -and $ExpectedVersion -ge 1) {
            # Fresh database, create structure
            Write-Verbose "Upgrading to version 1: creating database structure..."
            $this.CreateDatabaseStructure()
            $this.UpdateVersion(1)
        }
        if ($this.version -lt 2 -and $ExpectedVersion -ge 2) {
            Write-Verbose "Upgrading to version 2: transferring existing built-in images..."
            $this.TransferBuiltinImages([WslImageType]::Builtin)
            $this.TransferBuiltinImages([WslImageType]::Incus)
            $this.UpdateVersion(2)
        }
        if ($this.version -lt 3 -and $ExpectedVersion -ge 3) {
            Write-Verbose "Upgrading to version 3: adding GroupTag column to ImageSource table..."
            $this.AddImageSourceGroupTag()
            $this.UpdateVersion(3)
        }
        if ($this.version -lt 4 -and $ExpectedVersion -ge 4) {
            Write-Verbose "Upgrading to version 4: transferring local images..."
            $this.TransferLocalImages()
            $this.UpdateVersion(4)
        }
    }

    hidden [SQLiteHelper] $db
    hidden [int] $version
    static [FileInfo] $DatabaseFileName = $BaseImageDatabaseFilename
    static [int] $CurrentVersion = 3
    static [string] $DatabaseStructure = $BaseDatabaseStructure
    static [hashtable] $WslImageSources = $WslImageSources

    # Singleton instance
    hidden static [WslImageDatabase] $Instance
    hidden static [Timer] $SessionCloseTimer
    hidden static [int] $SessionCloseTimeout = 180000

    # static migration queries
    hidden static [string] $AddImageSourceGroupTagSql = @"
ALTER TABLE ImageSource ADD COLUMN [GroupTag] TEXT;
UPDATE ImageSource SET [GroupTag] = ImageSourceCache.Etag FROM ImageSourceCache WHERE ImageSource.Type = ImageSourceCache.Type;
"@
}

function Get-WslImageDatabase {
    if (-not [WslImageDatabase]::Instance) {
        [WslImageDatabase]::Instance = [WslImageDatabase]::new()
    }
    if (-not [WslImageDatabase]::Instance.IsOpen()) {
        [WslImageDatabase]::Instance.Open()
        [WslImageDatabase]::Instance.UpdateIfNeeded([WslImageDatabase]::CurrentVersion)

        # Put a session close timer of 3 minutes
        $timer = [Timer]::new([WslImageDatabase]::SessionCloseTimeout)
        $timer.AutoReset = $false
        if ([WslImageDatabase]::SessionCloseTimer) {
            [WslImageDatabase]::SessionCloseTimer.Dispose()
        }
        [WslImageDatabase]::SessionCloseTimer = $timer
        $null = Register-ObjectEvent -InputObject $timer -EventName Elapsed -Action {
            [WslImageDatabase]::Instance.Close()
        }
        $timer.Start()
    }
    return [WslImageDatabase]::Instance
}


function Close-WslImageDatabase {
    if ([WslImageDatabase]::Instance -and [WslImageDatabase]::Instance.IsOpen()) {
        [WslImageDatabase]::Instance.Close()
    }
    if ([WslImageDatabase]::SessionCloseTimer) {
        [WslImageDatabase]::SessionCloseTimer.Dispose()
        [WslImageDatabase]::SessionCloseTimer = $null
    }
}
