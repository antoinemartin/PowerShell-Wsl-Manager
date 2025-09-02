using namespace System.IO;

[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$BaseImageDatabaseFilename = [FileInfo]::new("$env:LOCALAPPDATA\Wsl\RootFS\images.db")
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

    [void] Open() {
        if ($this.IsOpen()) {
            throw [WslManagerException]::new("The image database is already open.")
        }

        # Create the database if it doesn't exist
        $this.db = [SQLiteHelper]::open([WslImageDatabase]::DatabaseFileName.FullName)

        # Get the current version from the database
        $rs = $this.db.ExecuteQuery("PRAGMA user_version;")
        $this.version = if ($rs.Count -gt 0) { $rs[0].version } else { 0 }
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

    [void] CreateDatabaseStructure() {
        if (-not $this.IsOpen()) {
            throw [WslManagerException]::new("The image database is not open.")
        }

        # Create the necessary tables and indexes
        $null = $this.db.ExecuteNonQuery([WslImageDatabase]::DatabaseStructure)
    }

    [void] UpdateIfNeeded() {
        if (-not $this.IsUpdatePending()) {
            return
        }

        if ($this.version -lt 1) {
            # Fresh database, create structure
            $this.CreateDatabaseStructure()
            $null = $this.db.ExecuteNonQuery("PRAGMA user_version = 1;")
            $this.version = 1
        }
    }

    hidden [SQLiteHelper] $db
    hidden [int] $version
    static [FileInfo] $DatabaseFileName = $BaseImageDatabaseFilename
    static [int] $CurrentVersion = 1
    static [string] $DatabaseStructure = $BaseDatabaseStructure
}
