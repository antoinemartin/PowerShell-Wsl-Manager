using namespace System.IO;

# The base URLs for Incus images
$base_incus_url = "https://images.linuxcontainers.org/images"
$base_rootfs_directory = [DirectoryInfo]::new("$env:LOCALAPPDATA\Wsl\RootFS")

class UnknownIncusDistributionException : System.SystemException {
    UnknownIncusDistributionException([string] $Os, [string]$Release) : base("Unknown Incus distribution with OS $Os and Release $Release. Check $base_incus_url.") {
    }
}

enum WslRootFileSystemState {
    NotDownloaded
    Synced
    Outdated
}


enum WslRootFileSystemType {
    Builtin
    Incus
    Local
    Uri
}

class UnknownDistributionException : System.SystemException {
    UnknownDistributionException([string] $Name) : base("Unknown distribution(s): $Name") {
    }
}

class WslRootFileSystemHash {
    [System.Uri]$Url
    [string]$Algorithm = 'SHA256'
    [string]$Type = 'sums'
    hidden [hashtable]$Hashes = @{}
    [bool]$Mandatory = $true

    [void]Retrieve() {
        if ($this.Type -ne 'docker') {
            Progress "Getting checksums from $($this.Url)..."
            try {
                $content = Sync-String $this.Url

                if ($this.Type -eq 'sums') {
                    ForEach ($line in $($content -split "`n")) {
                        if ([bool]$line) {
                            $item = $line -split '\s+'
                            $filename = $item[1] -replace '^\*', ''
                            $this.Hashes[$filename] = $item[0]
                        }
                    }
                }
                else {
                    $filename = $this.Url.Segments[-1] -replace '\.\w+$', ''
                    $this.Hashes[$filename] = $content.Trim()
                }
            }
            catch [System.Net.WebException] {
                if ($this.Mandatory) {
                    throw $_
                }
            }
        }
    }

    [string]GetExpectedHash([System.Uri]$Uri) {
        if ($this.Type -eq 'docker') {
            $Registry = $Uri.Host
            $Repository = $Uri.AbsolutePath.Trim('/')
            $Tag = $Uri.Fragment.TrimStart('#')
            $layer = Get-DockerImageLayerManifest -Registry $Registry -Image $Repository -Tag $Tag
            return $layer.digest -split ':' | Select-Object -Last 1
        } else {
            $Filename = $Uri.Segments[-1]
            if ($this.Hashes.ContainsKey($Filename)) {
                return $this.Hashes[$Filename]
            }
        }
        return $null
    }

    [string]DownloadAndCheckFile([System.Uri]$Uri, [FileInfo]$Destination) {
        $Filename = $Uri.Segments[-1]
        Write-Host "Downloading $($Uri) to $($Destination.FullName) with filename $Filename"
        if ($Uri.Scheme -ne 'docker' -and !($this.Hashes.ContainsKey($Filename)) -and $this.Mandatory) {
            throw "Missing hash for $Uri -> $Destination"
        }
        $temp = [FileInfo]::new($Destination.FullName + '.tmp')

        try {
            if ($Uri.Scheme -eq 'docker') {
                $Registry = $Uri.Host
                $Image = $Uri.AbsolutePath.Trim('/')
                $Tag = $Uri.Fragment.TrimStart('#')
                $expected = Get-DockerImageLayer -Registry $Registry -Image $Image -Tag $Tag -DestinationFile $temp.FullName
            } else {
                $expected = $this.Hashes[$Filename]
                Sync-File $Uri $temp
            }

            $actual = (Get-FileHash -Path $temp.FullName -Algorithm $this.Algorithm).Hash
            if (($null -ne $expected) -and ($expected -ne $actual)) {
                Remove-Item -Path $temp.FullName -Force
                throw "Bad hash for $Uri -> $Destination : expected $expected, got $actual"
            }
            Move-Item $temp.FullName $Destination.FullName -Force
            return $actual
        }
        finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }
}


class WslRootFileSystem: System.IComparable {


    [void]initFromBuiltin([PSCustomObject]$conf) {
        $dist_lower = $conf.Name.ToLower()

        $this.Type = [WslRootFileSystemType]::Builtin
        $this.Configured = $conf.Configured
        $this.Os = $conf.Os
        $this.Name = $dist_lower
        $this.Release = $conf.Release
        $this.Url = [System.Uri]$conf.Url
        $this.LocalFileName = "docker.$($dist_lower).rootfs.tar.gz"
        $this.HashSource = [WslRootFileSystemHash]($conf.Hash)
        $this.Username = $conf.Username
        $this.Uid = $conf.Uid

        if ($this.IsAvailableLocally) {
            $this.State = [WslRootFileSystemState]::Synced
            $this.UpdateHashIfNeeded();
            $this.WriteMetadata();
        }
    }

    WslRootFileSystem([PSCustomObject]$conf) {
        $this.initFromBuiltin($conf)
    }

    [void] init([string]$Name) {

        $this.Url = [System.Uri]$Name
        $dist_lower = $Name.ToLower()
        $dist_title = (Get-Culture).TextInfo.ToTitleCase($dist_lower)
        $distributions = $script:Distributions
        $this.Name = $dist_title

        # When the name is not an absolute URI, we try to find the file with the appropriate name
        if (-not $this.Url.IsAbsoluteUri) {

            if ($distributions.ContainsKey($dist_title)) {
                $this.initFromBuiltin($distributions[$dist_title])
                return
            }

            # we try different possible values
            $this.LocalFileName = "$dist_lower.rootfs.tar.gz"
            if (!$this.IsAvailableLocally) {
                $this.LocalFileName = "incus.$dist_lower.rootfs.tar.gz"
                if (!$this.IsAvailableLocally) {
                    # It must be docker builtin not shown
                    $this.Url = [System.Uri]::new("docker://ghcr.io/antoinemartin/powershell-wsl-manager/$dist_lower#latest")
                    $this.LocalFileName = "docker.$dist_lower.rootfs.tar.gz"
                } else {
                    $this.Os, $this.Release = $dist_lower -split '_'
                    $this.Url = Get-LxdRootFSUrl -Os $this.Os -Release $this.Release
                }
            }

            if ($this.IsAvailableLocally) {
                $this.State = [WslRootFileSystemState]::Synced
                if ($this.ReadMetaData()) {
                    # I have read my metadata, nothing else to do
                    return
                } else {
                    # Existing file with no metadata.
                    # TODO: Get metadata from existing file
                    if ($this.Type -ne [WslRootFileSystemType]::Builtin) {
                        throw "Existing file with no metadata: $($this.LocalFileName)"
                    } else {
                        Write-Warning "Existing file with no metadata: $($this.LocalFileName). Using defaults: $($this.Os) $($this.Release) $($this.Configured)"
                    }
                }
            }
        }

        if ($this.Url.IsAbsoluteUri) {
            # We have a URI, either because it comes like that or because this is a builtin
            $this.Type = [WslRootFileSystemType]::Uri
            switch ($this.Url.Scheme) {
                'incus' {
                    $this.Type = [WslRootFileSystemType]::Incus
                    $this.Os = $this.Url.Host
                    $this.Name = $this.Url.Host
                    $this.Username = 'root'
                    $this.Release = $this.Url.Fragment.TrimStart('#')
                    $this.Url = Get-LxdRootFSUrl -Os:$this.Os -Release:$this.Release
                    $this.LocalFileName = "incus.$($this.Name)_$($this.Release).rootfs.tar.gz"
                    $this.HashSource = [WslRootFileSystemHash]@{
                        Url       = [System.Uri]::new($this.Url, "SHA256SUMS")
                        Type      = 'sums'
                        Algorithm = 'SHA256'
                    }
                }
                'docker' {
                    $dist_lower = $this.Url.Segments[-1].ToLower()
                    $dist_title = (Get-Culture).TextInfo.ToTitleCase($dist_lower)
                    $this.HashSource = [WslRootFileSystemHash]@{
                        Type      = 'docker'
                    }
                    if ($this.Url.AbsolutePath -match '^/antoinemartin/powershell-wsl-manager' -and $distributions.ContainsKey($dist_title)) {
                        $this.initFromBuiltin($distributions[$dist_title])
                    } else {
                        $Registry = $this.Url.Host
                        $Tag = $this.Url.Fragment.TrimStart('#')
                        $Repository = $this.Url.AbsolutePath.Trim('/')
                        $manifest = Get-DockerImageLayerManifest -Registry $Registry -Image $Repository -Tag $Tag

                        # Default local filename
                        $this.Name = $dist_lower
                        $this.Os = ($this.Name -split "[-. ]")[0]
                        $this.Release = $Tag

                        # try to get more accurate information from the Image Labels
                        try {
                            $this.Release = $manifest.config.Labels['org.opencontainers.image.version']
                            $this.Os = (Get-Culture).TextInfo.ToTitleCase($manifest.config.Labels['org.opencontainers.image.flavor'])
                            $this.Username = if ($this.Configured) { $this.Os } else { 'root' }
                            if ($manifest.config.Labels.ContainsKey('com.kaweezle.wsl.rootfs.configured')) {
                                $this.Configured = $manifest.config.Labels['com.kaweezle.wsl.rootfs.configured'] -eq 'true'
                            }

                            if ($manifest.config.Labels.ContainsKey('com.kaweezle.wsl.rootfs.uid')) {
                                $this.Uid = [int]$manifest.config.Labels['com.kaweezle.wsl.rootfs.uid']
                            } else {
                                # We do this because configured might have changed
                                $this.Uid = if ($this.Configured) { 1000 } else { 0 }
                            }
                            if ($manifest.config.Labels.ContainsKey('com.kaweezle.wsl.rootfs.username')) {
                                $this.Username = $manifest.config.Labels['com.kaweezle.wsl.rootfs.username']
                            } else {
                                $this.Username = if ($this.Configured) { $this.Os } else { 'root' }
                            }
                        }
                        catch {
                            Information "Failed to get image labels from $($this.Url). Using defaults: $($this.Os) $($this.Release)"
                            # Do nothing
                        }
                        $this.LocalFileName = "docker." + $this.Name + ".rootfs.tar.gz"

                    }
                }
                Default {
                    $this.HashSource = [WslRootFileSystemHash]@{
                        Url       = [System.Uri]::new($this.Url, "SHA256SUMS")
                        Type      = 'sums'
                        Algorithm = 'SHA256'
                        Mandatory = $false
                    }
                    $this.LocalFileName = $this.Url.Segments[-1]
                    $this.Os = ($this.LocalFileName -split "[-. ]")[0]
                    $this.Name = $this.Os
                    $this.Username = 'root'
                }
            }
            if ($this.IsAvailableLocally) {
                $this.State = [WslRootFileSystemState]::Synced
                $this.ReadMetaData()
            }
            else {
                $this.State = [WslRootFileSystemState]::NotDownloaded
            }
        }
        else {
            # If the file is already present, take it
            throw [UnknownDistributionException] $Name
        }
    }

    WslRootFileSystem([string]$Name) {
        $this.init($Name)
    }

    WslRootFileSystem([FileInfo]$File) {
        $this.LocalFileName = $File.Name
        $this.State = [WslRootFileSystemState]::Synced

        $distributions = $script:Distributions

        if (!($this.ReadMetaData())) {
            if ($File.Name -imatch '^((?<prefix>\w+)\.)?(?<name>.+?)(\.rootfs)?\.tar\.gz$') {
                $this.Name = if ($matches['name'] -eq 'rootfs') { $matches['prefix'] } else { $matches['name'] }
                switch ($Matches['prefix']) {
                    'miniwsl' {
                        $this.Configured = $true
                        $this.Type = [WslRootFileSystemType]::Builtin
                        $this.Os = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                        $distributionKey = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                        if ($distributions.ContainsKey($distributionKey)) {
                            $this.Release = $distributions[$distributionKey]['Release']
                            $this.Url = $distributions[$distributionKey]['Url']
                        }
                     }
                     'incus' {
                        $this.Configured = $false
                        $this.Type = [WslRootFileSystemType]::Incus
                        $this.Os, $this.Release = $this.Name -Split '_'
                        $this.Url = Get-LxdRootFSUrl -Os $this.Os -Release $this.Release
                     }
                    Default {
                        $this.Os = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                        if ($distributions.ContainsKey($this.Name)) {
                            $this.initFromBuiltin($distributions[$this.Name])
                        } else {
                            # Ensure we have a tar.gz file
                            $this.Type = [WslRootFileSystemType]::Local
                            $this.Configured = $false
                            $this.Url = [System.Uri]::new($File.FullName).AbsoluteUri

                            if ($this.LocalFileName -notmatch '\.tar(\.gz)?$') {
                                $this.Os = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                                $this.Release = "unknown"
                            } else {

                                try {
                                    # Get os-release from the tar.gz file
                                    $osRelease = tar -xOf $File.FullName etc/os-release usr/lib/os-release
                                    $tarExitCode = $LASTEXITCODE
                                    if ($tarExitCode -ne 0) {
                                        Write-Warning "Failed to extract os-release: $osRelease"
                                        return
                                    }
                                    $osRelease = $osRelease | ConvertFrom-StringData
                                    if ($osRelease.ID) {
                                        $this.Os = (Get-Culture).TextInfo.ToTitleCase($osRelease.ID.Trim('"'))
                                    }
                                    if ($osRelease.BUILD_ID) {
                                        $this.Release = $osRelease.BUILD_ID.Trim('"')
                                    }
                                    if ($osRelease.VERSION_ID) {
                                        $this.Release = $osRelease.VERSION_ID.Trim('"')
                                    }
                                }
                                catch {
                                    # Clean up temp directory
                                    $this.Os = $this.Name
                                    $this.Release = "unknown"
                                }
                            }
                        }
                    }
                }

                $this.WriteMetadata()

            } else {
                throw [UnknownDistributionException] $File.Name
            }
        } else {
            # In case the JSON file doesn't contain the name
            if (-not $this.Name -and $File.Name -imatch '^((?<prefix>\w+)\.)?(?<name>.+?)(\.rootfs)?\.tar\.gz$') {
                $this.Name = if ($matches['name'] -eq 'rootfs') { $matches['prefix'] } else { $matches['name'] }
            }
        }
    }

    [string] ToString() {
        return $this.OsName
    }

    [int] CompareTo([object] $obj) {
        $other = [WslRootFileSystem]$obj
        return $this.LocalFileName.CompareTo($other.LocalFileName)
    }

    [void]WriteMetadata() {
        [PSCustomObject]@{
            Name              = $this.Name
            Os                = $this.Os
            Release           = $this.Release
            Type              = $this.Type.ToString()
            State             = $this.State.ToString()
            Url               = $this.Url
            Configured        = $this.Configured
            HashSource        = $this.HashSource
            FileHash          = $this.FileHash
            Username          = if ($null -eq $this.Username) { $this.Os } else { $this.Username }
            Uid              = $this.Uid
            # TODO: Checksums
        } | Remove-NullProperties | ConvertTo-Json | Set-Content -Path "$($this.File.FullName).json"
    }

    [bool] UpdateHashIfNeeded() {
        if (!$this.FileHash) {
            if (!$this.HashSource) {
                $this.HashSource = [WslRootFileSystemHash]@{
                    Algorithm = 'SHA256'
                }
            }
            $this.FileHash = (Get-FileHash -Path $this.File.FullName -Algorithm $this.HashSource.Algorithm).Hash
            return $true;
        }
        return $false;
    }

    [bool]ReadMetaData() {
        $metadata_filename = "$($this.File.FullName).json"
        $result = $false
        if (Test-Path $metadata_filename) {
            $metadata = Get-Content $metadata_filename | ConvertFrom-Json | Convert-PSObjectToHashtable
            $this.Os = $metadata.Os
            $this.Release = $metadata.Release
            $this.Type = [WslRootFileSystemType]($metadata.Type)
            $this.State = [WslRootFileSystemState]($metadata.State)
            if ($metadata.ContainsKey('Username')) {
                $this.Username = $metadata.Username
            } else {
                $this.Username = $this.Os
            }
            if ($metadata.ContainsKey('Uid')) {
                $this.Uid = $metadata.Uid
            }
            if (!$this.Url) {
                $this.Url = $metadata.Url
            }

            $this.Configured = $metadata.Configured
            if ($metadata.HashSource -and !$this.HashSource) {
                $this.HashSource = [WslRootFileSystemHash]($metadata.HashSource)
            }
            if ($metadata.FileHash) {
                $this.FileHash = $metadata.FileHash
            }

            $result = $true
        }

        # FIXME: This should be done elsewhere
        if ($this.UpdateHashIfNeeded()) {
            $this.WriteMetadata();
        }
        return $result
    }

    [bool]Delete() {
        if ($this.IsAvailableLocally) {
            Remove-Item -Path $this.File.FullName
            Remove-Item -Path "$($this.File.FullName).json" -ErrorAction SilentlyContinue
            $this.State = [WslRootFileSystemState]::NotDownloaded
            return $true
        }
        return $false
    }

    static [WslRootFileSystem[]] AllFileSystems() {
        $path = [WslRootFileSystem]::BasePath
        $files = $path.GetFiles("*.tar.gz")
        $local = [WslRootFileSystem[]]( $files | ForEach-Object { [WslRootFileSystem]::new($_) })

        $builtin = $script:Distributions.Keys | ForEach-Object {
            [WslRootFileSystem]::new($_)
        }
        return ($local + $builtin) | Sort-Object | Get-Unique
    }

    [WslRootFileSystemHash]GetHashSource() {
        if ($this.Type -eq [WslRootFileSystemType]::Local -and $null -ne $this.Url) {
            $source = [WslRootFileSystemHash]@{
                Url       = $this.Url
                Algorithm = 'SHA256'
                Type      = 'sums'
                Mandatory = $false
            }
            return $source
        } elseif ($this.HashSource) {
            $hashUrl = $this.HashSource.Url
            if ($null -ne $hashUrl -and [WslRootFileSystem]::HashSources.ContainsKey($hashUrl)) {
                return [WslRootFileSystem]::HashSources[$hashUrl]
            }
            else {
                $source = [WslRootFileSystemHash]($this.HashSource)
                $source.Retrieve()
                if ($null -ne $hashUrl) {
                    [WslRootFileSystem]::HashSources[$hashUrl] = $source
                }
                return $source
            }
        }
        return $null
    }

    [string]$Name
    [System.Uri]$Url

    [WslRootFileSystemState]$State
    [WslRootFileSystemType]$Type

    [bool]$Configured
    [string]$Username = "root"
    [int]$Uid = 0

    [string]$Os
    [string]$Release = "unknown"

    [string]$LocalFileName

    [PSCustomObject]$HashSource
    [string]$FileHash

    [hashtable]$Properties = @{}

    static [DirectoryInfo]$BasePath = $base_rootfs_directory

    # This is indexed by the URL
    static [hashtable]$HashSources = @{}
}
