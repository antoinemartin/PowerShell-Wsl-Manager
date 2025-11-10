using namespace System.IO;

# The base URLs for Incus images
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$base_incus_url = "https://images.linuxcontainers.org/images"
$ImageDatadir = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path -Path "$HOME" -ChildPath ".local/share" }
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$base_Image_directory = [DirectoryInfo]::new(@($ImageDatadir, "Wsl", "RootFS") -join [Path]::DirectorySeparatorChar)
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$image_split_regex = [regex]::new('^((?<prefix>\w+)\.)?(?<name>.+?)(\.rootfs)?\.tar\.(g|x)z$')

class UnknownIncusDistributionException : System.SystemException {
    UnknownIncusDistributionException([string] $Os, [string]$Release) : base("Unknown Incus image with OS $Os and Release $Release. Check $base_incus_url.") {
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
    Docker
}


[Flags()] enum WslImageSourceType {
    Local = 1
    Builtin = 2
    Incus = 4
    Uri = 8
    Docker = 16
    All = 31
}


class WslImageSource : System.IComparable {
    # Identity
    [Guid]$Id
    [string]$Name
    [string[]]$Tags
    [WslImageType]$Type

    # Distribution Info
    [string]$Distribution
    [string]$Release = "unknown"
    [bool]$Configured
    [string]$Username = "root"
    [int]$Uid = 0

    # Source Location
    [System.Uri]$Url

    # Local Info
    [string]$LocalFileName
    [long]$Size

    # Integrity & Metadata
    [System.Uri]$DigestUrl
    [string]$DigestAlgorithm = 'SHA256'
    [string]$DigestSource = 'sums'
    [string]$Digest

    # Lifecycle
    [System.DateTime]$CreationDate
    [System.DateTime]$UpdateDate
    [string]$GroupTag        # For bulk operations

    [void]initFromObject([PSCustomObject]$conf) {
        $dist_lower = $conf.Name.ToLower()

        $typeString = if ($conf.Type) { $conf.Type } else { 'Builtin' }

        if ($conf.Id) {
            $this.Id = [Guid]$conf.Id
        } else {
            $this.Id = [Guid]::Empty # This means it has not been persisted yet
        }

        $this.Type = [WslImageType]$typeString
        $this.Configured = $conf.Configured
        $this.Distribution = if ($conf.Distribution) { $conf.Distribution } else { $conf.Os }
        $this.Name = $dist_lower
        $this.Release = $conf.Release
        $this.Url = [System.Uri]$conf.Url
        $this.LocalFileName = if ($conf.LocalFileName) { $conf.LocalFileName } else { "docker.$($dist_lower).rootfs.tar.gz" }
        # TODO: Should be the same everywhere
        $DigestObject = if ($conf.Hash) { $conf.Hash } elseif ($conf.HashSource) { $conf.HashSource } else { $null }
        if ($DigestObject) {
            $this.DigestUrl = [System.Uri]$DigestObject.Url
            $this.DigestAlgorithm = $DigestObject.Algorithm
            $this.DigestSource = $DigestObject.Type
        } elseif ($conf.DigestAlgorithm) {
            $this.DigestUrl = $conf.DigestUrl
            $this.DigestAlgorithm = $conf.DigestAlgorithm
            $this.DigestSource = $conf.DigestSource
        } else {
            $this.DigestUrl = $null
            $this.DigestAlgorithm = 'SHA256'
            $this.DigestSource = 'sums'
        }
        if ($conf.Digest) {
            $this.Digest = $conf.Digest
        }
        if ($conf.FileHash) {
            $this.Digest = $conf.FileHash
        }

        $this.Username = if ($conf.Username) { $conf.Username } elseif ($this.Configured) { $this.Distribution } else { 'root' }
        $this.Uid = $conf.Uid

        if ($conf.CreationDate) {
            $this.CreationDate = [System.DateTime]$conf.CreationDate
        } else {
            $this.CreationDate = [System.DateTime]::Now
        }

        if ($conf.UpdateDate) {
            $this.UpdateDate = [System.DateTime]$conf.UpdateDate
        } else {
            $this.UpdateDate = [System.DateTime]::Now
        }

        if ($conf.Size) {
            $this.Size = [long]$conf.Size
        }
    }

    WslImageSource([PSCustomObject]$conf) {
        $this.initFromObject($conf)
    }

    [int] CompareTo([object] $obj) {
        $other = [WslImageSource]$obj
        return $this.Name.CompareTo($other.Name)
    }

    [PSCustomObject]ToObject() {
       return ([PSCustomObject]@{
            Id                = $this.Id.ToString()
            Name              = $this.Name
            Distribution      = $this.Distribution
            Release           = $this.Release
            Type              = $this.Type.ToString()
            Url               = $this.Url.AbsoluteUri
            Configured        = $this.Configured
            DigestUrl         = $this.DigestUrl.AbsoluteUri
            DigestAlgorithm   = $this.DigestAlgorithm
            DigestSource      = $this.DigestSource
            Digest            = $this.Digest
            Username          = if ($null -eq $this.Username) { $this.Distribution } else { $this.Username }
            Uid               = $this.Uid
            CreationDate      = $this.CreationDate.ToString("yyyy-MM-dd HH:mm:ss")
            UpdateDate        = $this.UpdateDate.ToString("yyyy-MM-dd HH:mm:ss")
            Size              = $this.Size
        } | Remove-NullProperties)
    }

    [string] GetFileSize()
    {
        return Format-FileSize -Bytes $this.Size
    }
}


class WslImage: System.IComparable {

    # An image source can be create from multiple sources:
    # - Builtin Metadata information
    # - LocalImage database record
    # - Local file
    # - Docker image
    # - URL

    [void]initFromBuiltin([PSCustomObject]$conf) {
        $dist_lower = $conf.Name.ToLower()

        $typeString = if ($conf.Type) { $conf.Type } else { 'Builtin' }

        if ($conf.Id) {
            $this.Id = [Guid]$conf.Id
        } else {
            $this.Id = [Guid]::NewGuid()
        }

        if ($conf.ImageSourceId) {
            $this.SourceId = [Guid]$conf.ImageSourceId
        }

        $this.Type = [WslImageType]$typeString
        $this.Configured = $conf.Configured
        $this.Os = $conf.Os
        $this.Name = $dist_lower
        $this.Release = $conf.Release
        $this.Url = [System.Uri]$conf.Url
        $this.LocalFileName = if ($conf.LocalFileName) { $conf.LocalFileName } else { "docker.$($dist_lower).rootfs.tar.gz" }
        # TODO: Should be the same everywhere
        $DigestSource = if ($conf.Hash) { $conf.Hash } elseif ($conf.HashSource) { $conf.HashSource } else { $null }
        if ($DigestSource) {
            $this.DigestUrl = [System.Uri]$DigestSource.Url
            $this.DigestAlgorithm = $DigestSource.Algorithm
            $this.DigestType = $DigestSource.Type
        }
        if ($conf.Digest) {
            $this.FileHash = $conf.Digest
        }
        if ($conf.FileHash) {
            $this.FileHash = $conf.FileHash
        }

        $this.Username = if ($conf.Username) { $conf.Username } elseif ($this.Configured) { $this.Os } else { 'root' }
        $this.Uid = $conf.Uid

        if ($conf.State) {
            $this.State = [WslImageState]$conf.State
        } else {
            $this.State = [WslImageState]::NotDownloaded
        }

        if ($conf.CreationDate) {
            $this.CreationDate = [System.DateTime]$conf.CreationDate
        } else {
            $this.CreationDate = [System.DateTime]::Now
        }

        if ($conf.UpdateDate) {
            $this.UpdateDate = [System.DateTime]$conf.UpdateDate
        } else {
            $this.UpdateDate = [System.DateTime]::Now
        }

        # if ($this.IsAvailableLocally) {
        #     $this.State = [WslImageState]::Synced
        #     $this.UpdateHashIfNeeded();
        #     $this.WriteMetadata();
        # }
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

            # If the name is the name of a builtin, we use that
            $found = Get-WslImageSource | Where-Object { $_.Name -eq $dist_title }
            if ($found) {
                $this.initFromBuiltin($found)
                return
            }

            # Try to find a file with the name
            $candidates = @([WslImage]::BasePath.EnumerateFiles("*.rootfs.tar.gz") | Where-Object {
                $_.Name -imatch [WslImage]::ImageSplitRegex -and (`
                ($matches['name'] -eq 'rootfs' -and $matches['prefix'] -eq $dist_lower) -or `
                ($matches['name'] -eq $dist_lower)
                )
            })

            if ($candidates.Count -eq 1) {
                $this.InitFromFile($candidates[0])
                return
            } elseif ($candidates.Count -gt 1) {
                throw [WslImageException]::new("Multiple candidates for $($Name): " + ($candidates | ForEach-Object { $_.Name } | Sort-Object) -join ', ')
            }

            # At this point, the only possibility is an unknown builtin
            $this.Url = [System.Uri]::new("docker://ghcr.io/antoinemartin/powershell-wsl-manager/$dist_lower#latest")
            $this.LocalFileName = "docker.$dist_lower.rootfs.tar.gz"
        }

        if ($this.Url.IsAbsoluteUri) {
            # We have a URI, either because it comes like that or because this is a builtin
            $this.Type = [WslImageType]::Uri
            switch ($this.Url.Scheme) {
                'incus' {
                    $_Os = $this.Url.Host
                    $_Release = $this.Url.Fragment.TrimStart('#')
                    $builtins = Get-WslImageSource -Type Incus | Where-Object { $_.Os -eq $_Os -and $_.Release -eq $_Release }
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
                    $this.DigestType = 'docker'
                    if ($this.Url.AbsolutePath -match '^/antoinemartin/powershell-wsl-manager') {
                        $found = Get-WslImageSource | Where-Object {$_.Name -eq $dist_title}
                        if ($found) {
                            # FIXME: If a local exists for this source, we should use it instead
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
                    $this.DigestType = 'sums'
                    $this.DigestAlgorithm = 'SHA256'
                    $this.DigestUrl = [System.Uri]::new($this.Url, "SHA256SUMS")
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

    [void]initFromFile([FileInfo]$File) {
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
                        $found = Get-WslImageSource | Where-Object { $_.Name -ieq $distributionKey }
                        if ($found) {
                            $this.initFromBuiltin($found)
                        } else {
                            Write-Warning "Did not find builtin image: $($this.Name)"
                        }
                     }
                     'incus' {
                        $this.Configured = $false
                        $this.Type = [WslImageType]::Incus
                        $this.Os, $this.Release = $this.Name -Split '_'
                        $found = Get-WslImageSource -Type Incus | Where-Object { $_.Os -eq $this.Os -and $_.Release -eq $this.Release }
                        if ($found) {
                            $this.initFromBuiltin($found)
                        }
                     }
                    Default {
                        $this.Os = (Get-Culture).TextInfo.ToTitleCase($this.Name)
                        $found = Get-WslImageSource | Where-Object { $_.Name -eq $this.Os }
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

                $this.State = [WslImageState]::Synced
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

    WslImage([FileInfo]$File) {
        $this.InitFromFile($File)
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
            Id                = $this.Id
            SourceId          = $this.SourceId
            Name              = $this.Name
            Os                = $this.Os
            Release           = $this.Release
            Type              = $this.Type.ToString()
            State             = $this.State.ToString()
            Url               = $this.Url
            Configured        = $this.Configured
            HashSource        = $this.GetHashSource()
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
            $this.FileHash = (Get-FileHash -Path $this.File.FullName -Algorithm $this.DigestAlgorithm).Hash
            return $true;
        }
        return $false;
    }

    [WslImage]RefreshState() {
        $this.State = if ($this.IsAvailableLocally) { [WslImageState]::Synced } else { [WslImageState]::NotDownloaded }
        return $this
    }

    [bool]ReadMetaData() {
        $metadata_filename = "$($this.File.FullName).json"
        $result = $false
        if (Test-Path $metadata_filename) {
            $metadata = Get-Content $metadata_filename | ConvertFrom-Json | Convert-PSObjectToHashtable
            $this.Os = $metadata.Os
            $this.Release = $metadata.Release
            $this.Type = [WslImageType]($metadata.Type)
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
            if ($metadata.HashSource) {
                $DigestSource = $metadata.HashSource
                $this.DigestUrl = [System.Uri]$DigestSource.Url
                $this.DigestAlgorithm = $DigestSource.Algorithm
                $this.DigestType = $DigestSource.Type
            }
            if ($metadata.FileHash) {
                $this.FileHash = $metadata.FileHash
            }
            $this.State = if ($this.IsAvailableLocally) { [WslImageState]::Synced } else { [WslImageState]::NotDownloaded }

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

    [PSCustomObject]GetHashSource() {
        $source = $null
        if ($this.Type -eq [WslImageType]::Docker -or $this.Type -eq [WslImageType]::Builtin) {
            $source = [PSCustomObject]@{
                Url       = $this.Url
                Type      = 'docker'
                Algorithm = 'SHA256'
                Mandatory = $true
            }
        } elseif ($this.Type -eq [WslImageType]::Local -and $null -ne $this.Url) {
            $source = [PSCustomObject]@{
                Url       = $this.Url
                Algorithm = 'SHA256'
                Type      = 'sums'
                Mandatory = $false
            }
        } elseif ($null -ne $this.DigestUrl) {
            $hashUrl = $this.DigestUrl
            if ([WslImage]::HashSources.ContainsKey($hashUrl)) {
                $source = [WslImage]::HashSources[$hashUrl]
            }
            else {
                $source = [PSCustomObject]@{
                    Url       = $hashUrl
                    Algorithm = $this.DigestAlgorithm
                    Type      = $this.DigestType
                    Mandatory = $false
                }
                if ($null -ne $hashUrl) {
                    [WslImage]::HashSources[$hashUrl] = $source
                }
            }
        }
        return $source
    }

    [void]DownloadAndCheckFile() {
        if ($this.IsAvailableLocally -and -not $this.Outdated) {
            return
        }
        $Destination = $this.File
        $Uri = $this.Url
        $temp = [FileInfo]::new($Destination.FullName + '.tmp')

        try {
            if ($Uri.Scheme -eq 'docker') {
                $Registry = $Uri.Host
                $Image = $Uri.AbsolutePath.Trim('/')
                $Tag = $Uri.Fragment.TrimStart('#')
                $expected = Get-DockerImage -Registry $Registry -Image $Image -Tag $Tag -DestinationFile $temp.FullName
            } else {
                # FIXME: This should be OnlineHash
                $expected = if ($this.Outdated) { $this.OnlineHash } else { $this.FileHash }
                Sync-File $Uri $temp
            }

            $actual = (Get-FileHash -Path $temp.FullName -Algorithm $this.DigestAlgorithm).Hash
            if (($null -ne $expected) -and ($expected -ne $actual)) {
                Remove-Item -Path $temp.FullName -Force
                throw [WslImageDownloadException]::new("Bad hash for $Uri -> $Destination : expected $expected, got $actual")
            }
            Move-Item $temp.FullName $Destination.FullName -Force
            $this.FileHash = $actual
            $this.State = [WslImageState]::Synced
            # TODO: Should persist state
        }
        finally {
            Remove-Item $temp -Force -ErrorAction SilentlyContinue
        }
        Write-Verbose "Downloaded Docker image $Uri to $Destination" -Verbose

    }


    [Guid]$Id
    [Guid]$SourceId
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

    [System.Uri]$DigestUrl
    [string]$DigestAlgorithm = 'SHA256'
    [string]$DigestType = 'sums'
    [string]$FileHash
    [System.DateTime]$CreationDate
    [System.DateTime]$UpdateDate

    [hashtable]$Properties = @{}

    static [DirectoryInfo]$BasePath = $base_Image_directory
    static [regex]$ImageSplitRegex = $image_split_regex

    # This is indexed by the URL
    static [hashtable]$HashSources = @{}
}
