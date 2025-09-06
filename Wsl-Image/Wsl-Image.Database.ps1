using namespace System.IO;
using namespace System.Timers;
using namespace System.Data;

[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
$DatabaseDatadir = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path -Path "$HOME" -ChildPath ".local/share" }
$BaseImageDatabaseFilename = [FileInfo]::new(@($DatabaseDatadir, "Wsl", "RootFS", "images.db") -join [Path]::DirectorySeparatorChar)
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$BaseDatabaseStructure = (Get-Content (Join-Path $PSScriptRoot "db.sqlite") -Raw)
$ImageSourceUpsert = (Get-Content (Join-Path $PSScriptRoot "image_source_upsert.sql") -Raw)

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
        $this.version = if ($rs.Count -gt 0) { $rs[0].user_version } else { 0 }
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
            }
        }
    }
    [void] SaveImageBuiltins([WslImageType]$Type, [PSCustomObject[]]$Images) {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }
        $query = [WslImageDatabase]::ImageSourceUpsert
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
                Digest        = if ($hash.Value) { $hash.Value } else { $null }
                DigestUrl     = $hash.Url
            }
            if (0 -ne $this.db.ExecuteNonQuery($query, $parameters)) {
                throw [WslManagerException]::new("Failed to insert or update image $($image.Name) into the database.")
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
            Write-Verbose "Inserted image $($image.Name) into ImageSource: $result."
        }

        # Delete the source file
        Remove-Item -Path $cacheFile -Force | Out-Null
    }

    [void] UpdateIfNeeded() {
        if (-not $this.IsUpdatePending()) {
            Write-Verbose "No update needed for the image database."
            return
        }

        Write-Verbose "Updating image database from version $($this.version) to version $([WslImageDatabase]::CurrentVersion)..."

        if ($this.version -lt 1 -and [WslImageDatabase]::CurrentVersion -ge 1) {
            # Fresh database, create structure
            Write-Verbose "Create Database Structure..."
            $this.CreateDatabaseStructure()
            $null = $this.db.ExecuteNonQuery("PRAGMA user_version = 1;VACUUM;")
            $this.version = 1
        }
        if ($this.version -lt 2 -and [WslImageDatabase]::CurrentVersion -ge 2) {
            Write-Verbose "Transfer existing built-in images..."
            $this.TransferBuiltinImages([WslImageType]::Builtin)
            $this.TransferBuiltinImages([WslImageType]::Incus)
            $null = $this.db.ExecuteNonQuery("PRAGMA user_version = 2;VACUUM;")
            $this.version = 2
        }
    }

    hidden [SQLiteHelper] $db
    hidden [int] $version
    static [FileInfo] $DatabaseFileName = $BaseImageDatabaseFilename
    static [int] $CurrentVersion = 2
    static [string] $DatabaseStructure = $BaseDatabaseStructure
    static [hashtable] $WslImageSources = $WslImageSources

    # Singleton instance
    hidden static [WslImageDatabase] $Instance
    hidden static [Timer] $SessionCloseTimer
    hidden static [int] $SessionCloseTimeout = 180000
    hidden static [string] $ImageSourceUpsert = $ImageSourceUpsert
}


function Get-WslImageDatabase {
    if (-not [WslImageDatabase]::Instance) {
        [WslImageDatabase]::Instance = [WslImageDatabase]::new()
    }
    if (-not [WslImageDatabase]::Instance.IsOpen()) {
        [WslImageDatabase]::Instance.Open()
        [WslImageDatabase]::Instance.UpdateIfNeeded()

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
