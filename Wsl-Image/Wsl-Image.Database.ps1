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

class WslImageDatabase {

    WslImageDatabase() {
        # Create the database directory (with parents) if it doesn't exist
        [WslImageDatabase]::DatabaseFileName.Directory.Create() | Out-Null
    }

    [bool] IsOpen() {
        return $null -ne $this.db
    }

    [void] AssertOpen() {
        if (-not $this.IsOpen()) {  # nocov
            throw [WslManagerException]::new("The image database is not open.")
        }
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
        $this.AssertOpen()
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
        $this.AssertOpen()
        $query = $this.db.CreateUpsertQuery("ImageSourceCache")
        $parameters = @{
            Type       = $Type.ToString()
            Url        = $CacheData.Url
            LastUpdate = $CacheData.LastUpdate
            Etag       = $CacheData.Etag
        }
        $this.db.ExecuteNonQuery($query, $parameters)
    }

    [PSCustomObject[]] GetImageSources([string]$QueryString, [hashtable]$Parameters = @{}) {
        $this.AssertOpen()
        $query = "SELECT * FROM ImageSource"
        if ($QueryString) {
            $query += " WHERE $QueryString;"
        } else {
            $query += ";"
        }
        Write-Verbose "Executing query to get image sources: $query with parameters: $($Parameters | ConvertTo-Json -Depth 5)"
        $dt = $this.db.ExecuteSingleQuery($query, $Parameters)
        if ($dt) {
            return $dt | ForEach-Object {
                [PSCustomObject]@{
                    Id               = $_.Id
                    Name            = $_.Name
                    Url             = if ([System.DBNull]::Value.Equals($_.Url)) { $null } else { $_.Url }
                    Type            = $_.Type -as [WslImageType]
                    Tags            = if ($_.Tags) { @($_.Tags -split ',') } else { @('none') }
                    Configured      = if ('TRUE' -eq $_.Configured) { $true } else { $false }
                    Username        = $_.Username
                    Uid             = $_.Uid
                    Distribution    = $_.Distribution
                    Release         = $_.Release
                    LocalFilename   = $_.LocalFilename
                    DigestSource    = $_.DigestSource
                    DigestAlgorithm = $_.DigestAlgorithm
                    DigestUrl       = if ([System.DBNull]::Value.Equals($_.DigestUrl)) { $null } else { $_.DigestUrl }
                    Digest          = if ([System.DBNull]::Value.Equals($_.Digest)) { $null } else { $_.Digest }
                    GroupTag        = if ([System.DBNull]::Value.Equals($_.GroupTag)) { $null } else { $_.GroupTag }
                    CreationDate    = [System.DateTime]::Parse($_.CreationDate)
                    UpdateDate      = [System.DateTime]::Parse($_.UpdateDate)
                    Size            = if ($_.Size -is [System.DBNull]) { 0 } else { $_.Size }
                }
            }
        } else {
            return @()
        }
    }

    [PSCustomObject[]] GetImageBuiltins([WslImageType]$Type) {
        return $this.GetImageSources("Type = @Type", @{ Type = $Type.ToString() })
    }

    [void] SaveImageBuiltins([WslImageType]$Type, [PSCustomObject[]]$Images, [string]$GroupTag = $null) {
        $this.AssertOpen()
        $query = $this.db.CreateUpsertQuery("ImageSource", @('Id'))
        foreach ($image in $Images) {
            $hash = if ($image.Hash) { $image.Hash } else { $image.HashSource }
            $parameters = @{
                Id            = [Guid]::NewGuid().ToString()
                Name          = $image.Name
                Tags          = if ($null -ne $image.Tags -and $image.Tags.Count -gt 0) { $image.Tags -join ',' } else { $image.Release }
                Url           = $image.Url
                Type          = $image.Type.ToString()
                Configured    = if ($image.Configured) { 'TRUE' } else { 'FALSE' }
                Username      = $image.Username
                Uid           = $image.Uid
                Distribution  = if ($image.Distribution) { $image.Distribution } else { $image.Os }
                Release       = $image.Release
                LocalFilename = $image.LocalFilename
                DigestSource  = $hash.Type
                DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
                Digest        = if ($image.FileHash) { $image.FileHash } elseif ($image.Digest) { $image.Digest } else { $null }
                DigestUrl     = $hash.Url
                GroupTag      = $GroupTag
                Size          = if ($image.PSObject.Properties.Match('Size')) { $image.Size } else { $null }
            }
            try {
                $this.db.ExecuteNonQuery($query, $parameters)
            } catch {
                throw [WslManagerException]::new("Failed to insert or update image $($image.Name) into the database. Exception: $($_.Exception.Message)", $_.Exception)
            }
        }
        Write-Verbose "Saved $($Images.Count) images of type $Type into the database with group tag $GroupTag. Removing old images..."
        try {
            $this.db.ExecuteNonQuery("DELETE FROM ImageSource WHERE Type = @Type AND GroupTag IS NOT NULL AND GroupTag IS NOT @GroupTag;", @{ Type = $Type.ToString(); GroupTag = $GroupTag })
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to remove old images of type $Type from the database. Exception: $($_.Exception.Message)", $_.Exception)
        }

        # Update local images state
        Write-Verbose "Updating local images state based on new image sources..."
        try {
            $this.db.ExecuteNonQuery("UPDATE LocalImage SET State = 'Outdated' FROM ImageSource WHERE LocalImage.ImageSourceId = ImageSource.Id AND LocalImage.Digest <> ImageSource.Digest;")
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to update local images state. Exception: $($_.Exception.Message)", $_.Exception)
        }
    }

    [void]SaveImageSource([PSCustomObject]$ImageSource) {
        $this.AssertOpen()
        $query = $this.db.CreateUpsertQuery("ImageSource", @('Id'))
        $hash = if ($ImageSource.Hash) { $ImageSource.Hash } else { $ImageSource.HashSource }
        if (-not $hash) {
            $hash = [PSCustomObject]@{
                Type      = $ImageSource.DigestSource
                Algorithm = $ImageSource.DigestAlgorithm
                Url       = $ImageSource.DigestUrl
            }
        }
        $parameters = @{
            Id            = $ImageSource.Id.ToString()
            Name          = $ImageSource.Name
            Tags          = if ($ImageSource.Tags) { $ImageSource.Tags -join ',' } else { $ImageSource.Release }
            Url           = $ImageSource.Url
            Type          = $ImageSource.Type.ToString()
            Configured    = if ($ImageSource.Configured) { 'TRUE' } else { 'FALSE' }
            Username      = $ImageSource.Username
            Uid           = $ImageSource.Uid
            Distribution  = $ImageSource.Distribution
            Release       = $ImageSource.Release
            LocalFilename = $ImageSource.LocalFilename
            DigestSource  = $hash.Type
            DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
            Digest        = if ($ImageSource.FileHash) { $ImageSource.FileHash } elseif ($ImageSource.Digest) { $ImageSource.Digest } else { $null }
            DigestUrl     = $hash.Url
            GroupTag      = if ($ImageSource.PSObject.Properties.Match('GroupTag')) { $ImageSource.GroupTag } else { $null }
            Size          = if ($ImageSource.PSObject.Properties.Match('Size')) { $ImageSource.Size } else { $null }
        }
        Write-Verbose "Inserting or updating image source $($ImageSource.Name) into the database with Id $($parameters.Id)..."
        try {
            $this.db.ExecuteNonQuery($query, $parameters)
        } catch {
            throw [WslManagerException]::new("Failed to insert or update image source $($ImageSource.Name) into the database. Exception: $($_.Exception.Message)", $_.Exception)
        }
        # If the query has done an update, we need to retrieve the previous id.
        # FIXME: This is not efficient. The upsert query should return the id (actually all fields) after the operation.
        $this.GetImageSources("Tags = @Tags AND Configured = @Configured AND Type = @Type AND Distribution = @Distribution", @{
            Tags = $parameters.Tags
            Configured = $parameters.Configured
            Type = $parameters.Type
            Distribution = $parameters.Distribution
        }) | ForEach-Object {
            Write-Verbose "Retrieved image source with Id $($_.Id) for image $($ImageSource.Name)..."
            $ImageSource.Id = $_.Id
        }
        Write-Verbose "Updating local images state based on new image source for Id $($ImageSource.Id)..."
        try {
            $this.db.ExecuteNonQuery("UPDATE LocalImage SET State = 'Outdated' FROM ImageSource WHERE ImageSource.Id = @Id AND LocalImage.ImageSourceId = ImageSource.Id AND LocalImage.Digest <> ImageSource.Digest;",@{ Id = $ImageSource.Id.ToString() })
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to update local images state. Exception: $($_.Exception.Message)", $_.Exception)
        }

    }

    [PSCustomObject[]] GetLocalImages([string]$QueryString, [hashtable]$Parameters = @{}) {
        $this.AssertOpen()
        $query = "SELECT * FROM LocalImage"
        if ($QueryString) {
            $query += " WHERE $QueryString;"
        } else {
            $query += ";"
        }
        $dt = $this.db.ExecuteSingleQuery($query, $Parameters)
        if ($null -eq $dt) {
            return @()
        }
        return $dt | ForEach-Object {
            [PSCustomObject]@{
                Id              = $_.Id
                ImageSourceId   = $_.ImageSourceId
                Name            = $_.Name
                Url             = if ([System.DBNull]::Value.Equals($_.Url)) { $null } else { $_.Url }
                Type            = $_.Type -as [WslImageType]
                Tags            = if ($_.Tags) { $_.Tags -split ',' } else { @() }
                Configured      = if ('TRUE' -eq $_.Configured) { $true } else { $false }
                Username        = $_.Username
                Uid             = $_.Uid
                Distribution    = $_.Distribution
                Release         = $_.Release
                LocalFilename   = $_.LocalFilename
                HashSource      = [PSCustomObject]@{
                    Type        = $_.DigestSource
                    Algorithm   = $_.DigestAlgorithm
                    Mandatory   = $true
                    Url         = if ([System.DBNull]::Value.Equals($_.DigestUrl)) { $null } else { $_.DigestUrl }
                }
                Digest          = if ([System.DBNull]::Value.Equals($_.Digest)) { $null } else { $_.Digest }
                State           = $_.State
                CreationDate    = [System.DateTime]::Parse($_.CreationDate)
                UpdateDate      = [System.DateTime]::Parse($_.UpdateDate)
                Size            = if ($_.Size -is [System.DBNull]) { 0 } else { $_.Size }
            }
        }
    }

    [PSCustomObject[]] GetLocalImages() {
        return $this.GetLocalImages($null, $null)
    }

    [void]SaveLocalImage([PSCustomObject]$LocalImage) {
        $this.AssertOpen()
        $query = $this.db.CreateUpsertQuery("LocalImage", @('Id'))
        $hash = if ($LocalImage.Hash) { $LocalImage.Hash } else { $LocalImage.HashSource }
        if (-not $hash) {
            $hash = [PSCustomObject]@{
                Type      = $LocalImage.DigestSource
                Algorithm = $LocalImage.DigestAlgorithm
                Url       = $LocalImage.DigestUrl
            }
        }
        $parameters = @{
            Id            = $LocalImage.Id.ToString()
            ImageSourceId = if ($LocalImage.SourceId) { $LocalImage.SourceId.ToString() } else { $null }
            Name          = $LocalImage.Name
            Tags          = if ($LocalImage.Tags) { $LocalImage.Tags -join ',' } else { $LocalImage.Release }
            Url           = $LocalImage.Url
            Type          = $LocalImage.Type.ToString()
            State         = $LocalImage.State.ToString()
            Configured    = if ($LocalImage.Configured) { 'TRUE' } else { 'FALSE' }
            Username      = $LocalImage.Username
            Uid           = $LocalImage.Uid
            Distribution  = $LocalImage.Distribution
            Release       = $LocalImage.Release
            LocalFilename = $LocalImage.LocalFilename
            DigestSource  = $hash.Type
            DigestAlgorithm = if ($hash.Algorithm) { $hash.Algorithm } else { "SHA256" }
            Digest        = if ($LocalImage.FileHash) { $LocalImage.FileHash } elseif ($LocalImage.Digest) { $LocalImage.Digest } else { $null }
            DigestUrl     = $hash.Url
            Size          = if ($LocalImage.PSObject.Properties.Match('Size')) { $LocalImage.Size } else { $null }
        }
        try {
            $this.db.ExecuteNonQuery($query, $parameters)
        } catch {
            throw [WslManagerException]::new("Failed to insert or update local image $($LocalImage.Name) into the database. Exception: $($_.Exception.Message)", $_.Exception)
        }
    }

    [PSCustomObject] CreateLocalImageFromImageSource([Guid]$ImageSourceId) {
        $this.AssertOpen()
        $dt = $this.db.ExecuteSingleQuery([WslImageDatabase]::CreateLocalImageSql, @{
            Id = [Guid]::NewGuid().ToString()
            ImageSourceId = $ImageSourceId.ToString()
        })
        if ($null -eq $dt -or $dt.Rows.Count -eq 0) {
            throw [WslManagerException]::new("Image source with ID $ImageSourceId not found.($dt)")
        }
        return $dt | ForEach-Object {
            [PSCustomObject]@{
                Id              = $_.Id
                ImageSourceId   = $_.ImageSourceId
                Name            = $_.Name
                Url             = if ([System.DBNull]::Value.Equals($_.Url)) { $null } else { $_.Url }
                Type            = $_.Type -as [WslImageType]
                Tags            = if ($_.Tags) { $_.Tags -split ',' } else { @() }
                Configured      = if ('TRUE' -eq $_.Configured) { $true } else { $false }
                Username        = $_.Username
                Uid             = $_.Uid
                Distribution    = $_.Distribution
                Release         = $_.Release
                LocalFilename   = $_.LocalFilename
                HashSource      = [PSCustomObject]@{
                    Type        = $_.DigestSource
                    Algorithm   = $_.DigestAlgorithm
                    Mandatory   = $true
                    Url         = if ([System.DBNull]::Value.Equals($_.DigestUrl)) { $null } else { $_.DigestUrl }
                }
                Digest          = if ([System.DBNull]::Value.Equals($_.Digest)) { $null } else { $_.Digest }
                State           = $_.State
                Size            = if ($_.Size -is [System.DBNull]) { 0 } else { $_.Size }
            }
        }
    }

    [void] RemoveLocalImage([Guid]$Id) {
        $this.AssertOpen()
        try {
            $this.db.ExecuteNonQuery("DELETE FROM LocalImage WHERE Id = @Id;", @{ Id = $Id.ToString() })
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to remove local image with ID $Id. Exception: $($_.Exception.Message)", $_.Exception)
        }
    }

    [void] RemoveImageSource([Guid]$Id) {
        $this.AssertOpen()
        try {
            $this.db.ExecuteNonQuery("DELETE FROM ImageSource WHERE Id = @Id;", @{ Id = $Id.ToString() })
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to remove image source with ID $Id. Exception: $($_.Exception.Message)", $_.Exception)
        }
    }

    [void] CreateDatabaseStructure() {
        $this.AssertOpen()

        # Create the necessary tables and indexes
        $this.db.ExecuteNonQuery([WslImageDatabase]::DatabaseStructure)
    }

    [void] TransferBuiltinImages([WslImageType]$Type = [WslImageType]::Builtin) {
        $this.AssertOpen()
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
        $this.db.ExecuteNonQuery($query, $parameters)

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
            $this.db.ExecuteNonQuery($query, $parameters)
        }

        # Delete the source file
        Remove-Item -Path $cacheFile -Force | Out-Null
    }

    [void] AddImageSourceGroupTag() {
        $this.AssertOpen()
        Write-Verbose "Adding GroupTag column to ImageSource table..."
        try {
            $this.db.ExecuteNonQuery([WslImageDatabase]::AddImageSourceGroupTagSql)
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to add GroupTag column to ImageSource table. Exception: $($_.Exception.Message)", $_.Exception)
        }
    }

    [void] AddImageSizeColumn() {
        $this.AssertOpen()
        Write-Verbose "Adding Size column to ImageSource and LocalImage tables..."
        try {
            $this.db.ExecuteNonQuery([WslImageDatabase]::AddSizeToImagesSql)
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to add Size column to ImageSource and LocalImage tables. Exception: $($_.Exception.Message)", $_.Exception)
        }
    }

    [void] AddUniqueIndexOnLocalImage() {
        $this.AssertOpen()
        Write-Verbose "Adding unique index on LocalImage (ImageSourceId, Name)..."
        try {
            $this.db.ExecuteNonQuery("CREATE UNIQUE INDEX IF NOT EXISTS IX_LocalImage_ImageSourceId_Name ON LocalImage (ImageSourceId, Name);")
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to add unique index on LocalImage (ImageSourceId, Name). Exception: $($_.Exception.Message)", $_.Exception)
        }
    }
    [void] ChangePrimaryKeyToTags() {
        $this.AssertOpen()
        Write-Verbose "Changing primary key of ImageSource from (Type, Distribution, Release, Configured) to (Type, Distribution, Tags, Configured)..."
        try {
            $this.db.ExecuteNonQuery([WslImageDatabase]::ChangePrimaryKeyToTagsSql)
        } catch {  # nocov
            throw [WslManagerException]::new("Failed to change primary key of ImageSource to use Tags instead of Release. Exception: $($_.Exception.Message)", $_.Exception)
        }
    }
    [void] TransferLocalImages([DirectoryInfo] $BasePath = $null) {
        $this.AssertOpen()
        if ($null -eq $BasePath) {
            $BasePath = [WslImage]::BasePath
        }
        Move-LocalWslImage -Database $this.db -BasePath $BasePath
    }

    [void]UpdateVersion([int]$NewVersion) {
        $this.AssertOpen()
        if ($NewVersion -le $this.version) {  # nocov
            Write-Warning "Attempted to update database version to $NewVersion, which is not greater than the current version $($this.version). Skipping."
            return
        }
        $this.db.ExecuteNonQuery("PRAGMA user_version = $NewVersion;VACUUM;")
        $this.version = $NewVersion
    }

    [void] UpdateIfNeeded([int]$ExpectedVersion) {
        $this.AssertOpen()

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
            $this.TransferLocalImages($null)
            $this.UpdateVersion(4)
        }
        if ($this.version -lt 5 -and $ExpectedVersion -ge 5) {
            Write-Verbose "Upgrading to version 5: adding Size column to ImageSource and LocalImage tables..."
            $this.AddImageSizeColumn()
            $this.UpdateVersion(5)
        }
        if ($this.version -lt 6 -and $ExpectedVersion -ge 6) {
            Write-Verbose "Upgrading to version 6: adding unique index on LocalImage (ImageSourceId, Name)..."
            $this.AddUniqueIndexOnLocalImage()
            $this.UpdateVersion(6)
        }
        if ($this.version -lt 7 -and $ExpectedVersion -ge 7) {
            Write-Verbose "Upgrading to version 7: changing primary key to use Tags instead of Release..."
            $this.ChangePrimaryKeyToTags()
            $this.UpdateVersion(7)
        }
    }

    hidden [SQLiteHelper] $db
    hidden [int] $version
    static [FileInfo] $DatabaseFileName = $BaseImageDatabaseFilename
    static [int] $CurrentVersion = 7
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

    hidden static [string] $CreateLocalImageSql = @"
INSERT INTO LocalImage (Id,ImageSourceId,Name,Tags,Url,State,Type,Configured,Username,Uid,Distribution,Release,LocalFilename,DigestSource,DigestAlgorithm,DigestUrl,Digest,Size)
SELECT @Id,Id,Name,Tags,Url,'NotDownloaded',Type,Configured,Username,Uid,Distribution,Release,LocalFilename,DigestSource,DigestAlgorithm,DigestUrl,Digest,Size
FROM ImageSource WHERE Id = @ImageSourceId
ON CONFLICT(ImageSourceId, Name) DO UPDATE SET
    Url = excluded.Url,
    Type = excluded.Type,
    Configured = excluded.Configured,
    Username = excluded.Username,
    Uid = excluded.Uid,
    Distribution = excluded.Distribution,
    Release = excluded.Release,
    LocalFilename = excluded.LocalFilename,
    DigestSource = excluded.DigestSource,
    DigestAlgorithm = excluded.DigestAlgorithm,
    DigestUrl = excluded.DigestUrl,
    Digest = excluded.Digest,
    Size = excluded.Size,
    UpdateDate = CURRENT_TIMESTAMP
RETURNING *;
"@

    hidden static [string] $AddSizeToImagesSql = @"
ALTER TABLE ImageSource ADD COLUMN [Size] INTEGER;
ALTER TABLE LocalImage ADD COLUMN [Size] INTEGER;
"@

    hidden static [string] $ChangePrimaryKeyToTagsSql = @"
-- Create a new table with the correct primary key
DROP TABLE IF EXISTS ImageSource_new;
UPDATE ImageSource SET Tags = [Release] WHERE Tags IS NULL OR Tags = '';
CREATE TABLE ImageSource_new (
    Id TEXT,
    CreationDate TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    UpdateDate TEXT NOT NULL DEFAULT CURRENT_TIMESTAMP,
    Name TEXT NOT NULL,
    Tags TEXT,
    Url TEXT,
    Type TEXT NOT NULL DEFAULT 'Builtin',
    Configured TEXT NOT NULL DEFAULT 'FALSE',
    Username TEXT NOT NULL DEFAULT 'root',
    Uid INTEGER NOT NULL DEFAULT 0,
    Distribution TEXT,
    [Release] TEXT,
    LocalFilename TEXT,
    DigestSource TEXT DEFAULT 'docker',
    DigestAlgorithm TEXT DEFAULT 'SHA256',
    DigestUrl TEXT,
    Digest TEXT,
    [GroupTag] TEXT,
    [Size] INTEGER,
    PRIMARY KEY (Type, Distribution, Tags, Configured),
    UNIQUE (Id)
);

-- Copy data from old table to new table
INSERT INTO ImageSource_new SELECT * FROM ImageSource;

-- Drop the old table
DROP TABLE ImageSource;

-- Rename the new table
ALTER TABLE ImageSource_new RENAME TO ImageSource;
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
