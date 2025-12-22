using namespace System.IO;

# The base URLs for Incus images
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$base_incus_url = "https://images.linuxcontainers.org/images"
$ImageDatadir = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path -Path "$HOME" -ChildPath ".local/share" }
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$base_Image_directory = [DirectoryInfo]::new(@($ImageDatadir, "Wsl", "RootFS") -join [Path]::DirectorySeparatorChar)
[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$image_split_regex = [regex]::new('^((?<prefix>\w+)\.)?(?<name>.+?)(\.rootfs)?\.tar\.(g|x)z$')

class UnknownDistributionException : System.SystemException {
    UnknownDistributionException([string] $Os, [string]$Release, [string]$Type) : base("Unknown image with OS $Os and Release $Release and type $Type.") {
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

    [void]InitFromObject([PSCustomObject]$conf) {
        $dist_lower = $conf.Name.ToLower()

        if ($conf.Id) {
            $this.Id = [Guid]$conf.Id
        }

        if ($this.Type -eq [WslImageType]::Builtin -and $conf.Type) {
            $this.Type = [WslImageType]$conf.Type
        }
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

        if ($conf.GroupTag) {
            $this.GroupTag = $conf.GroupTag
        }
        if ($conf.Tags) {
            $this.Tags = $conf.Tags
        }
        if ((-not $this.Url -and $this.Type -ne [WslImageType]::Local) -or -not $this.Distribution -or -not $this.Release) {
            throw [WslManagerException]::new("Invalid image source configuration for $($this.Name): URL, Distribution, and Release are required.")
        }
    }

    WslImageSource([PSCustomObject]$conf) {
        $this.InitFromObject($conf)
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
            LocalFileName     = $this.LocalFileName
            Tags              = if ($this.Tags) { $this.Tags } else { @() }
        } | Remove-NullProperties)
    }

    [string] GetFileSize()
    {
        return Format-FileSize -Bytes $this.Size
    }
}


class WslImage: System.IComparable {


    [Guid]$Id
    [Guid]$SourceId
    [string]$Name

    [WslImageState]$State
    [WslImageType]$Type

    [System.DateTime]$CreationDate
    [System.DateTime]$UpdateDate

    [System.Uri]$Url
    [bool]$Configured
    [string]$Username = "root"
    [int]$Uid = 0

    [string]$Os
    [string]$Release = "unknown"

    [string]$LocalFileName
    [long]$Size

    [System.Uri]$DigestUrl
    [string]$DigestAlgorithm = 'SHA256'
    [string]$DigestType = 'sums'
    [string]$FileHash

    [WslImageSource]$Source

    static [DirectoryInfo]$BasePath = $base_Image_directory
    static [regex]$ImageSplitRegex = $image_split_regex


    [void]InitFromObject([PSCustomObject]$conf) {
        $dist_lower = $conf.Name.ToLower()

        $typeString = if ($conf.Type) { $conf.Type } else { 'Builtin' }

        if ($conf.Id) {
            $this.Id = [Guid]$conf.Id
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

        if ($conf.Size) {
            $this.Size = [long]$conf.Size
        }
    }

    WslImage([PSCustomObject]$conf) {
        $this.InitFromObject($conf)
    }

    [void]UpdateFromSource() {
        if ($null -ne $this.Source) {
            $this.DigestAlgorithm = $this.Source.DigestAlgorithm
            $this.DigestUrl = $this.Source.DigestUrl
            $this.DigestType = $this.Source.DigestSource
            $this.FileHash = $this.Source.Digest
            $this.LocalFileName = $this.Source.LocalFilename
            $this.Size = $this.Source.Size
            $this.Url = $this.Source.Url
            $this.Release = $this.Source.Release
            $this.State = if ($this.IsAvailableLocally) { [WslImageState]::Synced } else { [WslImageState]::NotDownloaded }
        }
    }

    WslImage([PSCustomObject]$conf, [WslImageSource]$Source) {
        $this.InitFromObject($conf)
        $this.Source = $Source
    }

    [string] ToString() {
        return $this.OsName
    }

    [int] CompareTo([object] $obj) {
        $other = [WslImage]$obj
        return $this.LocalFileName.CompareTo($other.LocalFileName)
    }

    [string] GetFileSize()
    {
        if ($this.IsAvailableLocally) {
            return Format-FileSize -Bytes $this.File.Length
        }
        return Format-FileSize -Bytes $this.Size
    }

    [PSCustomObject]ToObject() {
       return ([PSCustomObject]@{
            Id                = $this.Id.ToString()
            SourceId          = $this.SourceId.ToString()
            Name              = $this.Name
            Os                = $this.Os
            Release           = $this.Release
            Type              = $this.Type.ToString()
            State             = $this.State.ToString()
            Url               = $this.Url.AbsoluteUri
            Configured        = $this.Configured
            HashSource        = $this.GetHashSource()
            FileHash          = $this.FileHash
            Username          = if ($null -eq $this.Username) { $this.Os } else { $this.Username }
            Uid               = $this.Uid
            Size              = $this.Size
            LocalFileName    = $this.LocalFileName
            CreationDate      = $this.CreationDate.ToString("yyyy-MM-dd HH:mm:ss")
            UpdateDate        = $this.UpdateDate.ToString("yyyy-MM-dd HH:mm:ss")
            # TODO: Checksums
        } | Remove-NullProperties)
    }

    [bool] UpdateHashIfNeeded() {
        if ($this.IsAvailableLocally) {
            $oldHash = $this.FileHash
            $this.FileHash = Invoke-GetFileHash -Path $this.File.FullName -Algorithm $this.DigestAlgorithm
            if ($oldHash -ne $this.FileHash) {
                return $true;
            }
        }
        return $false;
    }

    [bool]RefreshState() {
        $result = $false
        if ($this.State -eq [WslImageState]::NotDownloaded -and $this.IsAvailableLocally) {
            $this.State = [WslImageState]::Synced
            $this.UpdateHashIfNeeded() | Out-Null
            $result = $true
        }
        if ($null -ne $this.Source -and $this.FileHash -ne $this.Source.Digest) {
            if ($this.State -eq [WslImageState]::Synced) {
                $this.State = [WslImageState]::Outdated
                $result = $true
            } else { # Not downloaded, so just update from source
                $this.UpdateFromSource()
                $result = $true
            }
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
        $hashSource = $null
        if ($this.Type -eq [WslImageType]::Docker -or $this.Type -eq [WslImageType]::Builtin) {
            $hashSource = [PSCustomObject]@{
                Url       = $this.Url.AbsoluteUri
                Type      = 'docker'
                Algorithm = 'SHA256'
                Mandatory = $true
            }
        } elseif ($this.Type -eq [WslImageType]::Local -and $null -ne $this.Url) {
            $hashSource = [PSCustomObject]@{
                Url       = $this.Url.AbsoluteUri
                Algorithm = 'SHA256'
                Type      = 'sums'
                Mandatory = $false
            }
        } elseif ($null -ne $this.DigestUrl) {
            $hashSource = [PSCustomObject]@{
                Url       = $this.DigestUrl.AbsoluteUri
                Algorithm = $this.DigestAlgorithm
                Type      = $this.DigestType
                Mandatory = $false
            }
        }
        return $hashSource
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

            $actual = Invoke-GetFileHash -Path $temp.FullName -Algorithm $this.DigestAlgorithm
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
        Write-Verbose "Downloaded image $Uri to $Destination"
    }
}
