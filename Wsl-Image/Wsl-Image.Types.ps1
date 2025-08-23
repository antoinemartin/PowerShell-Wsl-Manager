using namespace System.IO;

# The base URLs for Incus images
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$base_incus_url = "https://images.linuxcontainers.org/images"
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$base_Image_directory = [DirectoryInfo]::new("$env:LOCALAPPDATA\Wsl\RootFS")
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$image_split_regex = [regex]::new('^((?<prefix>\w+)\.)?(?<name>.+?)(\.rootfs)?\.tar\.(g|x)z$')

class UnknownIncusDistributionException : System.SystemException {
    UnknownIncusDistributionException([string] $Os, [string]$Release) : base("Unknown Incus distribution with OS $Os and Release $Release. Check $base_incus_url.") {
    }
}

enum WslImageState {
    NotDownloaded
    Synced
    Outdated
}


enum WslImageType {
    Builtin
    Incus
    Local
    Uri
}

[Flags()] enum WslImageSource {
    Local = 1
    Builtins = 2
    Incus = 4
    All = 7
}


class WslImageHash {
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
            $layer = Get-DockerImageManifest -Registry $Registry -Image $Repository -Tag $Tag
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
        if ($Uri.Scheme -ne 'docker' -and !($this.Hashes.ContainsKey($Filename)) -and $this.Mandatory) {
            throw [WslImageDownloadException]::new("Missing hash for $Uri -> $Destination")
        }
        $temp = [FileInfo]::new($Destination.FullName + '.tmp')

        try {
            if ($Uri.Scheme -eq 'docker') {
                $Registry = $Uri.Host
                $Image = $Uri.AbsolutePath.Trim('/')
                $Tag = $Uri.Fragment.TrimStart('#')
                $expected = Get-DockerImage -Registry $Registry -Image $Image -Tag $Tag -DestinationFile $temp.FullName
            } else {
                $expected = $this.Hashes[$Filename]
                Sync-File $Uri $temp
            }

            $actual = (Get-FileHash -Path $temp.FullName -Algorithm $this.Algorithm).Hash
            if (($null -ne $expected) -and ($expected -ne $actual)) {
                Remove-Item -Path $temp.FullName -Force
                throw [WslImageDownloadException]::new("Bad hash for $Uri -> $Destination : expected $expected, got $actual")
            }
            Move-Item $temp.FullName $Destination.FullName -Force
            return $actual
        }
        finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
    }
}


class WslImage: System.IComparable {


    [void]initFromBuiltin([PSCustomObject]$conf) {
        $dist_lower = $conf.Name.ToLower()

        $typeString = if ($conf.Type) { $conf.Type } else { 'Builtin' }

        $this.Type = [WslImageType]$typeString
        $this.Configured = $conf.Configured
        $this.Os = $conf.Os
        $this.Name = $dist_lower
        $this.Release = $conf.Release
        $this.Url = [System.Uri]$conf.Url
        $this.LocalFileName = if ($conf.LocalFileName) { $conf.LocalFileName } else { "docker.$($dist_lower).rootfs.tar.gz" }
        # TODO: Should be the same everywhere
        if ($conf.Hash) {
            $this.HashSource = [WslImageHash]($conf.Hash)
        } else {
            if ($conf.HashSource) {
                $this.HashSource = [WslImageHash]($conf.HashSource)
            }
        }

        $this.Username = $conf.Username
        $this.Uid = $conf.Uid

        if ($this.IsAvailableLocally) {
            $this.State = [WslImageState]::Synced
            $this.UpdateHashIfNeeded();
            $this.WriteMetadata();
        }
    }

    WslImage([PSCustomObject]$conf) {
        $this.initFromBuiltin($conf)
    }

    [void] init([string]$Name) {

        $this.Url = [System.Uri]$Name
        $dist_lower = $Name.ToLower()
        $dist_title = (Get-Culture).TextInfo.ToTitleCase($dist_lower)
        $this.Name = $dist_title

        # When the name is not an absolute URI, we try to find the file with the appropriate name
        if (-not $this.Url.IsAbsoluteUri) {

            $found = Get-WslBuiltinImage | Where-Object { $_.Name -eq $dist_title }
            if ($found) {
                $this.initFromBuiltin($found)
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
                    $this.Type = [WslImageType]::Incus
                    $this.Os, $this.Release = $dist_lower -split '_'
                    $builtins = Get-WslBuiltinImage -Source Incus | Where-Object { $_.Os -eq $this.Os -and $_.Release -eq $this.Release }
                    if ($builtins) {
                        $this.initFromBuiltin($builtins[0])
                        return
                    }
                }
            }

            if ($this.IsAvailableLocally) {
                $this.State = [WslImageState]::Synced
                if ($this.ReadMetaData()) {
                    # I have read my metadata, nothing else to do
                    return
                } else {
                    # Existing file with no metadata.
                    # TODO: Get metadata from existing file
                    if ($this.Type -ne [WslImageType]::Builtin) {
                        throw [WslImageException]::new("Existing file with no metadata: $($this.LocalFileName)")
                    } else {
                        Write-Warning "Existing file with no metadata: $($this.LocalFileName). Using defaults: $($this.Os) $($this.Release) $($this.Configured)"
                    }
                }
            }
        }

        if ($this.Url.IsAbsoluteUri) {
            # We have a URI, either because it comes like that or because this is a builtin
            $this.Type = [WslImageType]::Uri
            switch ($this.Url.Scheme) {
                'incus' {
                    $_Os = $this.Url.Host
                    $_Release = $this.Url.Fragment.TrimStart('#')
                    $builtins = Get-WslBuiltinImage -Source Incus | Where-Object { $_.Os -eq $_Os -and $_.Release -eq $_Release }
                    if ($builtins) {
                        $this.initFromBuiltin($builtins[0])
                        return
                    } else {
                        throw [UnknownIncusDistributionException]::new($_Os, $_Release)
                    }
                }
                'docker' {
                    $dist_lower = $this.Url.Segments[-1].ToLower()
                    $dist_title = (Get-Culture).TextInfo.ToTitleCase($dist_lower)
                    $this.HashSource = [WslImageHash]@{
                        Type      = 'docker'
                    }
                    if ($this.Url.AbsolutePath -match '^/antoinemartin/powershell-wsl-manager') {
                        $found = Get-WslBuiltinImage | Where-Object {$_.Name -eq $dist_title}
                        if ($found) {
                            $this.initFromBuiltin($found)
                            return
                        }
                    }
                    $Registry = $this.Url.Host
                    $Tag = $this.Url.Fragment.TrimStart('#')
                    $Repository = $this.Url.AbsolutePath.Trim('/')
                    $manifest = Get-DockerImageManifest -Registry $Registry -Image $Repository -Tag $Tag

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
                Default {
                    $this.HashSource = [WslImageHash]@{
                        Url       = [System.Uri]::new($this.Url, "SHA256SUMS")
                        Type      = 'sums'
                        Algorithm = 'SHA256'
                        Mandatory = $false
                    }
                    $this.LocalFileName = $this.Url.Segments[-1]
                    $this.Os = ($this.LocalFileName -split "[-. ]")[0]
                    $this.Name = $this.Os
                    $this.Username = 'root'
                    $this.Uid = 0
                    $this.Configured = $false
                }
            }
            if ($this.IsAvailableLocally) {
                $this.State = [WslImageState]::Synced
                $this.ReadMetaData()
            }
            else {
                $this.State = [WslImageState]::NotDownloaded
            }
        }
        else {
            # If the file is already present, take it
            throw [UnknownWslImageException]::new($Name)
        }
    }

    WslImage([string]$Name) {
        $this.init($Name)
    }

    WslImage([FileInfo]$File) {
        $this.LocalFileName = $File.Name
        $this.State = [WslImageState]::Synced

        if (!($this.ReadMetaData())) {
            if ($File.Name -imatch [WslImage]::ImageSplitRegex) {
                $this.Name = if ($matches['name'] -eq 'rootfs') { $matches['prefix'] } else { $matches['name'] }
                switch ($Matches['prefix']) {
                    { $_ -in 'miniwsl', 'docker' } {
                        $this.Configured = $true
                        $this.Type = [WslImageType]::Builtin
                        $this.Os = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                        $distributionKey = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                        $found = Get-WslBuiltinImage | Where-Object { $_.Name -ieq $distributionKey }
                        if ($found) {
                            $this.initFromBuiltin($found)
                        } else {
                            Write-Warning "Did not find builtin distribution: $($this.Name)"
                        }
                     }
                     'incus' {
                        $this.Configured = $false
                        $this.Type = [WslImageType]::Incus
                        $this.Os, $this.Release = $this.Name -Split '_'
                        $found = Get-WslBuiltinImage -Source Incus | Where-Object { $_.Os -eq $this.Os -and $_.Release -eq $this.Release }
                        if ($found) {
                            $this.initFromBuiltin($found)
                        }
                     }
                    Default {
                        $this.Os = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                        $found = Get-WslBuiltinImage | Where-Object { $_.Name -eq $this.Os }
                        if ($found) {
                            $this.initFromBuiltin(@($found)[0])
                        } else {
                            # Ensure we have a tar.gz file
                            $this.Type = [WslImageType]::Local
                            $this.Configured = $false
                            $this.Url = [System.Uri]::new($File.FullName).AbsoluteUri

                            if ($this.LocalFileName -notmatch '\.tar(\.gz)?$') {
                                $this.Os = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                                $this.Release = "unknown"
                            } else {

                                try {
                                    # Get os-release from the tar.gz file
                                    $osRelease = Invoke-Tar -xOf $File.FullName etc/os-release usr/lib/os-release
                                    $osRelease = $osRelease -replace '=\s*"(.*?)"', '=$1'
                                    $osRelease = $osRelease | ConvertFrom-StringData
                                    if ($osRelease.ID) {
                                        $this.Os = (Get-Culture).TextInfo.ToTitleCase($osRelease.ID)
                                    }
                                    if ($osRelease.BUILD_ID) {
                                        $this.Release = $osRelease.BUILD_ID
                                    }
                                    if ($osRelease.VERSION_ID) {
                                        $this.Release = $osRelease.VERSION_ID
                                    }
                                }
                                catch {
                                    # Clean up temp directory
                                    $this.Os = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                                    $this.Release = "unknown"
                                }
                            }
                        }
                    }
                }

                $this.WriteMetadata()

            } else {
                throw [UnknownWslImageException]::new($File.Name)
            }
        } else {
            # In case the JSON file doesn't contain the name
            if (-not $this.Name -and $File.Name -imatch [WslImage]::ImageSplitRegex) {
                $this.Name = if ($matches['name'] -eq 'rootfs') { $matches['prefix'] } else { $matches['name'] }
            }
        }
    }

    [string] ToString() {
        return $this.OsName
    }

    [int] CompareTo([object] $obj) {
        $other = [WslImage]$obj
        return $this.LocalFileName.CompareTo($other.LocalFileName)
    }

    [PSCustomObject]ToObject() {
       return ([PSCustomObject]@{
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
        } | Remove-NullProperties)
    }

    [void]WriteMetadata() {
       $this.ToObject() | ConvertTo-Json | Set-Content -Path "$($this.File.FullName).json"
    }

    [bool] UpdateHashIfNeeded() {
        if (!$this.FileHash) {
            if (!$this.HashSource) {
                $this.HashSource = [WslImageHash]@{
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
            $this.Type = [WslImageType]($metadata.Type)
            $this.State = [WslImageState]($metadata.State)
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
                $this.HashSource = [WslImageHash]($metadata.HashSource)
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
            $this.State = [WslImageState]::NotDownloaded
            return $true
        }
        return $false
    }

    static [WslImage[]] LocalFileSystems() {
        $path = [WslImage]::BasePath
        $files = $path.GetFiles("*.tar.gz")
        $local = [WslImage[]]( $files | ForEach-Object { [WslImage]::new($_) })

        return $local
    }

    [WslImageHash]GetHashSource() {
        if ($this.Type -eq [WslImageType]::Local -and $null -ne $this.Url) {
            $source = [WslImageHash]@{
                Url       = $this.Url
                Algorithm = 'SHA256'
                Type      = 'sums'
                Mandatory = $false
            }
            return $source
        } elseif ($this.HashSource) {
            $hashUrl = $this.HashSource.Url
            if ($null -ne $hashUrl -and [WslImage]::HashSources.ContainsKey($hashUrl)) {
                return [WslImage]::HashSources[$hashUrl]
            }
            else {
                $source = [WslImageHash]($this.HashSource)
                $source.Retrieve()
                if ($null -ne $hashUrl) {
                    [WslImage]::HashSources[$hashUrl] = $source
                }
                return $source
            }
        }
        return $null
    }

    [string]$Name
    [System.Uri]$Url

    [WslImageState]$State
    [WslImageType]$Type

    [bool]$Configured
    [string]$Username = "root"
    [int]$Uid = 0

    [string]$Os
    [string]$Release = "unknown"

    [string]$LocalFileName

    [PSCustomObject]$HashSource
    [string]$FileHash

    [hashtable]$Properties = @{}

    static [DirectoryInfo]$BasePath = $base_Image_directory
    static [regex]$ImageSplitRegex = $image_split_regex

    # This is indexed by the URL
    static [hashtable]$HashSources = @{}
}
