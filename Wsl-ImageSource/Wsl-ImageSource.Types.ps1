# Copyright 2022 Antoine Martin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

using namespace System.IO;

[Flags()] enum WslImageSourceType {
    Local = 1
    Builtin = 2
    Incus = 4
    Uri = 8
    Docker = 16
    All = 31
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
