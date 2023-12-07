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

. "$PSScriptRoot\download.ps1"


# The base URLs for LXD images
$base_lxd_url = "https://uk.lxd.images.canonical.com/images"
# We don't support ARM yet
$lxd_directory_suffix = "amd64/default"
$lxd_rootfs_name = "rootfs.tar.xz"
$base_wsl_directory = "$env:LOCALAPPDATA\Wsl"
$base_rootfs_directory = [DirectoryInfo]::new("$base_wsl_directory\RootFS")


class UnknownLXDDistributionException : System.SystemException {
    UnknownLXDDistributionException([string] $Os, [string]$Release) : base("Unknown LXD distribution with OS $Os and Release $Release. Check $base_lxd_url.") {
    }
}

<#
.SYNOPSIS
Returns the URL of the root filesystem of the LXD image for the specified OS
and Release.

.DESCRIPTION
LXD images made by canonical (https://uk.lxd.images.canonical.com/) are 
"rolling". In Consequence, getting the current root filesystem URL for a distro
Involves browsing the distro directory to get the directory name of the last 
build.

.PARAMETER Os
Parameter The name of the OS (debian, ubuntu, alpine, rockylinux, centos, ...)

.PARAMETER Release
The release (version). Highly dependent on the distro. For rolling release 
distros (e.g. Arch), use `current`.

.OUTPUTS
string
The URL of the root filesystem for the requested distribution.

.EXAMPLE
Get-LxdRootFSUrl almalinux 8
Returns the URL of the root filesystem for almalinux version 8

.EXAMPLE
Get-LxdRootFSUrl -Os centos -Release 9-Stream
Returns the URL of the root filesystem for CentOS Stream version 9
#>
function Get-LxdRootFSUrl {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Os,
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Release
    )
    
    $url = "$base_lxd_url/$Os/$Release/$lxd_directory_suffix"

    try {
        $last_release_directory = (Invoke-WebRequest $url).Links | Select-Object -Last 1 -ExpandProperty "href"
    }
    catch {
        throw [UnknownLXDDistributionException]::new($OS, $Release)
    }
    

    return [System.Uri]"$url/$($last_release_directory.Substring(2))$lxd_rootfs_name"
}


enum WslRootFileSystemState {
    NotDownloaded
    Synced
    Outdated
}


enum WslRootFileSystemType {
    Builtin
    LXD
    Local
    Uri
}

class UnknownDistributionException : System.SystemException {
    UnknownDistributionException([string] $Name) : base("Unknown distribution(s): $Name") {
    }
}

function Emoji {
    param (
        [string]$code
    )
    $EmojiIcon = [System.Convert]::toInt32($code, 16)
    return [System.Char]::ConvertFromUtf32($EmojiIcon)
}

$script:HourGlass = Emoji "231B"
$script:PartyPopper = Emoji "1F389"
$script:Eyes = Emoji "1F440"

function Progress {
    param (
        [string]$message
    )
    Write-Host "$script:HourGlass " -NoNewline
    Write-Host -ForegroundColor DarkGray $message
}

function Success {
    param (
        [string]$message
    )
    Write-Host "$script:PartyPopper " -NoNewline
    Write-Host -ForegroundColor DarkGreen $message
}

function Information {
    param (
        [string]$message
    )
    Write-Host "$script:Eyes " -NoNewline
    Write-Host -ForegroundColor DarkYellow $message
}


# This function is here to mock the download in unit tests
function Sync-File {
    param(
        [System.Uri]$Url,
        [FileInfo]$File
    )
    Progress "Downloading $($Url)..."
    Start-Download $Url $File.FullName
}

# Another function to mock in unit tests
function Sync-String {
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [System.Uri]$Url
    )
    process {
        return (New-Object Net.WebClient).DownloadString($Url)
    }
}


class WslRootFileSystemHash {
    [System.Uri]$Url
    [string]$Algorithm
    [string]$Type
    [hashtable]$Hashes = @{}
    [bool]$Mandatory = $true

    [void]Retrieve() {
        Progress "Getting checksums from $($this.Url)..."
        try {
            $content = Sync-String $this.Url

            if ($this.Type -eq 'sums') {
                ForEach ($line in $($content -split "`n")) {
                    if ([bool]$line) {
                        $item = $line -split '\s+'
                        $this.Hashes[$item[1]] = $item[0]
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

    [string]DownloadAndCheckFile([System.Uri]$Uri, [FileInfo]$Destination) {
        $Filename = $Uri.Segments[-1]
        if (!($this.Hashes.ContainsKey($Filename)) -and $this.Mandatory) {
            return $null
        }

        $expected = $this.Hashes[$Filename]
        $temp = [FileInfo]::new($Destination.FullName + '.tmp')

        try {
            Sync-File $Uri $temp

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

    [void] init([string]$Name, [bool]$Configured) {

        # Get the root fs file locally
        if ($Name -match '^lxd:(?<Os>[^:]+):(?<Release>[^:]+)$') {
            $this.Type = [WslRootFileSystemType]::LXD
            $this.Os = $Matches.Os
            $this.Release = $Matches.Release
            $this.Url = Get-LxdRootFSUrl -Os:$this.Os -Release:$this.Release
            $this.AlreadyConfigured = $Configured
            $this.LocalFileName = "lxd.$($this.Os)_$($this.Release).rootfs.tar.gz"
            $this.HashSource = [PSCustomObject]@{
                Url       = [System.Uri]::new($this.Url, "SHA256SUMS")
                Type      = 'sums'
                Algorithm = 'SHA256'
            }
        }
        else {
            $this.Url = [System.Uri]$Name
            if ($this.Url.IsAbsoluteUri) {
                $this.LocalFileName = $this.Url.Segments[-1]
                $this.AlreadyConfigured = $Configured
                $this.Os = ($this.LocalFileName -split "[-. ]")[0]
                $this.Type = [WslRootFileSystemType]::Uri
                $this.HashSource = [PSCustomObject]@{
                    Url       = [System.Uri]::new($this.Url, "SHA256SUMS")
                    Type      = 'sums'
                    Algorithm = 'SHA256'
                    Mandatory = $false
                }
            }
            else {
                $this.Url = $null
                $dist_lower = $Name.ToLower()
                $dist_title = (Get-Culture).TextInfo.ToTitleCase($dist_lower)
            
                $urlKey = 'Url'
                $hashKey = 'Hash'
                $rootfs_prefix = ''
                if ($true -eq $Configured) { 
                    $urlKey = 'ConfiguredUrl' 
                    $hashKey = 'ConfiguredHash'
                    $rootfs_prefix = 'miniwsl.'
                }
    
                $this.LocalFileName = "$rootfs_prefix$dist_lower.rootfs.tar.gz"
    
                if ([WslRootFileSystem]::Distributions.ContainsKey($dist_title)) {
                    $properties = [WslRootFileSystem]::Distributions[$dist_title]
                    if (!$properties.ContainsKey($urlKey)) {
                        throw "No configured Root filesystem for $dist_title."
                    }
                    $this.Os = $dist_title
                    $this.Url = [System.Uri]$properties[$urlKey]
                    $this.AlreadyConfigured = $Configured
                    $this.Type = [WslRootFileSystemType]::Builtin
                    $this.Release = $properties['Release']
                    $this.HashSource = $properties[$hashKey]
                }
                elseif ($this.IsAvailableLocally) {
                    $this.Type = [WslRootFileSystemType]::Local
                    $this.Os = $Name
                    $this.AlreadyConfigured = $true # We assume it's already configured, but actually we don't know
                }
                else {
                    # If the file is already present, take it
                    throw [UnknownDistributionException] $Name
                }    
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

    WslRootFileSystem([string]$Name, [bool]$Configured) {
        $this.init($Name, $Configured)
    }

    WslRootFileSystem([string]$Name) {
        $this.init($Name, $false)
    }

    WslRootFileSystem([FileInfo]$File) {

        $this.LocalFileName = $File.Name
        $this.State = [WslRootFileSystemState]::Synced

        if (!($this.ReadMetaData())) {
            $name = $File.Name -replace '\.rootfs\.tar\.gz$', ''
            if ($name.StartsWith("miniwsl.")) {
                $this.AlreadyConfigured = $true
                $this.Type = [WslRootFileSystemType]::Builtin
                $name = (Get-Culture).TextInfo.ToTitleCase(($name -replace 'miniwsl\.', ''))
                $this.Os = $name
                $this.Release = [WslRootFileSystem]::Distributions[$name]['Release']
                $this.Url = [WslRootFileSystem]::Distributions[$name]['ConfiguredUrl']
            }
            elseif ($name.StartsWith("lxd.")) {
                $this.AlreadyConfigured = $false
                $this.Type = [WslRootFileSystemType]::LXD
                $this.Os, $this.Release = ($name -replace 'lxd\.', '') -Split '_'
                $this.Url = Get-LxdRootFSUrl -Os $this.Os -Release $this.Release
            }
            else {
                $name = (Get-Culture).TextInfo.ToTitleCase($name)
                $this.Os = $name
                if ([WslRootFileSystem]::Distributions.ContainsKey($name)) {
                    $this.AlreadyConfigured = $false
                    $this.Type = [WslRootFileSystemType]::Builtin
                    $this.Release = [WslRootFileSystem]::Distributions[$name]['Release']
                    $this.Url = [WslRootFileSystem]::Distributions[$name]['Url']
                }
                else {
                    $this.Type = [WslRootFileSystemType]::Local
                    $this.Os = $name
                    $this.Release = "unknown"
                    $this.AlreadyConfigured = $true
                }
            }
            $this.WriteMetadata()
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
            Os                = $this.Os
            Release           = $this.Release
            Type              = $this.Type.ToString()
            State             = $this.State.ToString()
            Url               = $this.Url
            AlreadyConfigured = $this.AlreadyConfigured
            HashSource        = $this.HashSource
            FileHash          = $this.FileHash
            # TODO: Checksums
        } | ConvertTo-Json | Set-Content -Path "$($this.File.FullName).json"
    }

    [bool]ReadMetaData() {
        $metadata_filename = "$($this.File.FullName).json"
        $result = $false
        $rewrite_it = $false
        if (Test-Path $metadata_filename) {
            $metadata = Get-Content $metadata_filename | ConvertFrom-Json
            $this.Os = $metadata.Os
            $this.Release = $metadata.Release
            $this.Type = [WslRootFileSystemType]($metadata.Type)
            $this.State = [WslRootFileSystemState]($metadata.State)
            if (!$this.Url) {
                $this.Url = $metadata.Url
            }
            
            $this.AlreadyConfigured = $metadata.AlreadyConfigured
            if ($metadata.HashSource -and !$this.HashSource) {
                $this.HashSource = $metadata.HashSource
            }
            if ($metadata.FileHash) {
                $this.FileHash = $metadata.FileHash
            }
            
            $result = $true
        }
        
        if (!$this.FileHash) {
            if (!$this.HashSource) {
                $this.HashSource = [PSCustomObject]@{
                    Algorithm = 'SHA256'
                }
            }
            $this.FileHash = (Get-FileHash -Path $this.File.FullName -Algorithm $this.HashSource.Algorithm).Hash
            $rewrite_it = $true
        }

        if ($rewrite_it) {
            $this.WriteMetadata()
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
    
        $builtin = [WslRootFileSystem]::Distributions.keys | ForEach-Object {
            [WslRootFileSystem]::new($_, $false)
            [WslRootFileSystem]::new($_, $true)
        }
        return ($local + $builtin) | Sort-Object | Get-Unique
    }

    [WslRootFileSystemHash]GetHashSource() {
        if ($this.HashSource) {
            $hashUrl = $this.HashSource.Url
            if ([WslRootFileSystem]::HashSources.ContainsKey($hashUrl)) {
                return [WslRootFileSystem]::HashSources[$hashUrl]
            }
            else {
                $source = [WslRootFileSystemHash]($this.HashSource)
                $source.Retrieve()
                [WslRootFileSystem]::HashSources[$hashUrl] = $source
                return $source
            }
        }
        return $null
    }

    [System.Uri]$Url

    [WslRootFileSystemState]$State
    [WslRootFileSystemType]$Type
    
    [bool]$AlreadyConfigured

    [string]$Os
    [string]$Release = "unknown"

    [string]$LocalFileName

    [PSCustomObject]$HashSource
    [string]$FileHash

    static [DirectoryInfo]$BasePath = $base_rootfs_directory

    # This is indexed by the URL
    static [hashtable]$HashSources = @{}

    static $BuiltinHashes = [PSCustomObject]@{
        Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
        Algorithm = 'SHA256'
        Type      = 'sums'
    }

    static $Distributions = @{
        Arch     = @{
            Url            = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/archlinux.rootfs.tar.gz'
            Hash           = [WslRootFileSystem]::BuiltinHashes
            ConfiguredUrl  = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.arch.rootfs.tar.gz'
            ConfiguredHash = [WslRootFileSystem]::BuiltinHashes
            Release        = 'current'
        }
        Alpine   = @{
            Url            = 'https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.0-x86_64.tar.gz'
            Hash           = [PSCustomObject]@{
                Url       = 'https://dl-cdn.alpinelinux.org/alpine/v3.18/releases/x86_64/alpine-minirootfs-3.18.0-x86_64.tar.gz.sha256'
                Algorithm = 'SHA256'
                Type      = 'sums'
            }
            ConfiguredUrl  = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.alpine.rootfs.tar.gz'
            ConfiguredHash = [WslRootFileSystem]::BuiltinHashes
            Release        = '3.18'
        }
        Ubuntu   = @{
            Url            = 'https://cloud-images.ubuntu.com/wsl/mantic/current/ubuntu-mantic-wsl-amd64-wsl.rootfs.tar.gz'
            Hash           = [PSCustomObject]@{
                Url       = 'https://cloud-images.ubuntu.com/wsl/mantic/current/SHA256SUMS'
                Algorithm = 'SHA256'
                Type      = 'sums'
            }
            ConfiguredUrl  = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.ubuntu.rootfs.tar.gz'
            ConfiguredHash = [WslRootFileSystem]::BuiltinHashes
            Release        = 'mantic'
        }
        Debian   = @{
            # This is the root fs used to produce the official Debian slim docker image
            # see https://github.com/docker-library/official-images/blob/master/library/debian
            # see https://github.com/debuerreotype/docker-debian-artifacts
            Url            = "https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/bullseye/rootfs.tar.xz"
            Hash           = [PSCustomObject]@{
                Url       = 'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/bullseye/rootfs.tar.xz.sha256'
                Algorithm = 'SHA256'
                Type      = 'single'
            }
            ConfiguredUrl  = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.debian.rootfs.tar.gz"
            ConfiguredHash = [WslRootFileSystem]::BuiltinHashes
            Release        = 'bullseye'
        }
        OpenSuse = @{
            Url            = "https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz"
            Hash           = [PSCustomObject]@{
                Url       = 'https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz.sha256'
                Algorithm = 'SHA256'
                Type      = 'sums'
            }
            ConfiguredUrl  = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.opensuse.rootfs.tar.gz"
            ConfiguredHash = [WslRootFileSystem]::BuiltinHashes
            Release        = 'tumbleweed'
        }
    }
}

<#
.SYNOPSIS
Creates a new FileSystem hash holder.

.DESCRIPTION
The WslRootFileSystemHash object holds checksum information for one or more 
distributions in order to check it upon download and determine if the filesystem
has been updated.

Note that the checksums are not downloaded until the `Retrieve()` method has been
called on the object.

.PARAMETER Url
The Url where the checksums are located.

.PARAMETER Algorithm
The checksum algorithm. Nowadays, we find mostly SHA256.

.PARAMETER Type
Type can either be `sums` in which case the file contains one 
<checksum> <filename> pair per line, or `single` and just contains the hash for 
the file which name is the last segment of the Url minus the extension. For 
instance, if the URL is `https://.../rootfs.tar.xz.sha256`, we assume that the
checksum it contains is for the file named `rootfs.tar.xz`.

.EXAMPLE
New-WslRootFileSystemHash https://cloud-images.ubuntu.com/wsl/kinetic/current/SHA256SUMS
Creates the hash source for several files with SHA256 (default) algorithm.

.EXAMPLE
New-WslRootFileSystemHash https://.../rootfs.tar.xz.sha256 -Type `single`
Creates the hash source for the rootfs.tar.xz file with SHA256 (default) algorithm.

.NOTES
General notes
#>
function New-WslRootFileSystemHash {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $false)]
        [string]$Algorithm = 'SHA256',
        [Parameter(Mandatory = $false)]
        [string]$Type = 'sums'
    )

    return [WslRootFileSystemHash]@{
        Url       = $Url
        Algorithm = $Algorithm
        Type      = $Type
    }

}


function New-WslRootFileSystem {
    <#
    .SYNOPSIS
    Creates a WslRootFileSystem object.

    .DESCRIPTION
    WslRootFileSystem object retrieve and provide information about available root
    filesystems.

    .PARAMETER Distribution
    The identifier of the distribution. It can be an already known name:
    - Arch
    - Alpine
    - Ubuntu
    - Debian

    It also can be the URL (https://...) of an existing filesystem or a 
    distribution name saved through Export-Wsl.

    It can also be a name in the form:

        lxd:<os>:<release> (ex: lxd:rockylinux:9)

    In this case, it will fetch the last version the specified image in
    https://uk.lxd.images.canonical.com/images. 

    .PARAMETER Configured
    Whether the distribution is configured. This parameter is relevant for Builtin 
    distributions.

    .PARAMETER Path
    The path of the root filesystem. Should be a file ending with `rootfs.tar.gz`.

    .PARAMETER File
    A FileInfo object of the compressed root filesystem.

    .EXAMPLE
    New-WslRootFileSystem lxd:alpine:3.17
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        LXD alpine       3.17                   Synced lxd.alpine_3.17.rootfs.tar.gz
    The WSL root filesystem representing the lxd alpine 3.17 image.

    .EXAMPLE
    New-WslRootFileSystem alpine -Configured
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.17                   Synced miniwsl.alpine.rootfs.tar.gz
    The builtin configured Alpine root filesystem.

    .LINK
    Get-WslRootFileSystem
    #>
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Distribution,
        [Parameter(Position = 1, ParameterSetName = 'Name', Mandatory = $false)]
        [switch]$Configured,
        [Parameter(ParameterSetName = 'Path', ValueFromPipeline = $true, Mandatory = $true)]
        [string]$Path,
        [Parameter(ParameterSetName = 'File', ValueFromPipeline = $true, Mandatory = $true)]
        [FileInfo]$File
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            return [WslRootFileSystem]::new($Distribution, $Configured)
        }
        else {
            if ($PSCmdlet.ParameterSetName -eq "Path") {
                $File = [FileInfo]::new($Path)
            }
            return [WslRootFileSystem]::new($File)
        }
    }
    
}

function Sync-WslRootFileSystem {
    <#
    .SYNOPSIS
    Synchronize locally the specified WSL root filesystem.

    .DESCRIPTION
    If the root filesystem is not already present locally, downloads it from its 
    original URL.

    .PARAMETER Distribution
    The identifier of the distribution. It can be an already known name:
    - Arch
    - Alpine
    - Ubuntu
    - Debian

    It also can be the URL (https://...) of an existing filesystem or a 
    distribution name saved through Export-Wsl.

    It can also be a name in the form:

        lxd:<os>:<release> (ex: lxd:rockylinux:9)

    In this case, it will fetch the last version the specified image in
    https://uk.lxd.images.canonical.com/images. 

    .PARAMETER Configured
    Whether the distribution is configured. This parameter is relevant for Builtin 
    distributions.

    .PARAMETER RootFileSystem
    The WslRootFileSystem object to process.

    .PARAMETER Force
    Force the synchronization even if the root filesystem is already present locally.

    .INPUTS
    The WSLRootFileSystem Objects to process.

    .OUTPUTS
    The path of the WSL root filesytem. It is suitable as input for the 
    `wsl --import` command.

    .EXAMPLE
    Sync-WslRootFileSystem Alpine -Configured
    Syncs the already configured builtin Alpine root filesystem.

    .EXAMPLE
    Sync-WslRootFileSystem Alpine -Force
    Re-download the Alpine builtin root filesystem.

    .EXAMPLE
    Get-WslRootFileSystem -State NotDownloaded -Os Alpine | Sync-WslRootFileSystem
    Synchronize the Alpine root filesystems not already synced

    .EXAMPLE
     New-WslRootFileSystem alpine -Configured | Sync-WslRootFileSystem | % { &wsl --import test $env:LOCALAPPDATA\Wsl\test $_ }
     Create a WSL distro from a synchronized root filesystem.

    .LINK
    New-WslRootFileSystem
    Get-WslRootFileSystem
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Distribution,
        [Parameter(ParameterSetName = 'Name', Mandatory = $false)]
        [switch]$Configured,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "RootFileSystem")]
        [WslRootFileSystem[]]$RootFileSystem,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $RootFileSystem = New-WslRootFileSystem $Distribution -Configured:$Configured
        }

        if ($null -ne $RootFileSystem) {
            $RootFileSystem | ForEach-Object {
                $fs = $_
                [FileInfo] $dest = $fs.File

                If (!([WslRootFileSystem]::BasePath.Exists)) {
                    if ($PSCmdlet.ShouldProcess([WslRootFileSystem]::BasePath.Create(), "Create base path")) {
                        Progress "Creating rootfs base path [$([WslRootFileSystem]::BasePath)]..."
                        [WslRootFileSystem]::BasePath.Create()
                    }
                }
            
        
                if (!$dest.Exists -Or $_.Outdated -Or $true -eq $Force) {
                    if ($PSCmdlet.ShouldProcess($fs.Url, "Sync locally")) {
                        try {
                            $fs.FileHash = $fs.GetHashSource().DownloadAndCheckFile($fs.Url, $fs.File)
                        }
                        catch [Exception] {
                            throw "Error while loading distro [$($fs.OsName)] on $($fs.Url): $($_.Exception.Message)"
                            return $null
                        }
                        $fs.State = [WslRootFileSystemState]::Synced
                        $fs.WriteMetadata()
                        Success "[$($fs.OsName)] Synced at [$($dest.FullName)]."
                    }
                }
                else {
                    Information "[$($fs.OsName)] Root FS already at [$($dest.FullName)]."
                }
            
                return $dest.FullName
            }
        
        }
    }
    
}


function Get-WslRootFileSystem {
    <#
    .SYNOPSIS
        Gets the WSL root filesystems installed on the computer and the ones available.
    .DESCRIPTION
        The Get-WslRootFileSystem cmdlet gets objects that represent the WSL root filesystems available on the computer.
        This can be the ones already synchronized as well as the Bultin filesystems available.
    .PARAMETER Name
        Specifies the name of the filesystem.
    .PARAMETER Os
        Specifies the Os of the filesystem.
    .PARAMETER Type
        Specifies the type of the filesystem.
    .PARAMETER Outdated
        Return the list of outdated root filesystems. Works mainly on Builtin
        distributions.
    .INPUTS
        System.String
        You can pipe a distribution name to this cmdlet.
    .OUTPUTS
        WslRootFileSystem
        The cmdlet returns objects that represent the WSL root filesystems on the computer.
    .EXAMPLE
        Get-WslRootFileSystem
           Type Os           Release                 State Name
           ---- --           -------                 ----- ----
        Builtin Alpine       3.17            NotDownloaded alpine.rootfs.tar.gz
        Builtin Arch         current                Synced arch.rootfs.tar.gz
        Builtin Debian       bullseye               Synced debian.rootfs.tar.gz
          Local Docker       unknown                Synced docker.rootfs.tar.gz
          Local Flatcar      unknown                Synced flatcar.rootfs.tar.gz
            LXD almalinux    8                      Synced lxd.almalinux_8.rootfs.tar.gz
            LXD almalinux    9                      Synced lxd.almalinux_9.rootfs.tar.gz
            LXD alpine       3.17                   Synced lxd.alpine_3.17.rootfs.tar.gz
            LXD alpine       edge                   Synced lxd.alpine_edge.rootfs.tar.gz
            LXD centos       9-Stream               Synced lxd.centos_9-Stream.rootfs.ta...
            LXD opensuse     15.4                   Synced lxd.opensuse_15.4.rootfs.tar.gz
            LXD rockylinux   9                      Synced lxd.rockylinux_9.rootfs.tar.gz
        Builtin Alpine       3.17                   Synced miniwsl.alpine.rootfs.tar.gz
        Builtin Arch         current                Synced miniwsl.arch.rootfs.tar.gz
        Builtin Debian       bullseye               Synced miniwsl.debian.rootfs.tar.gz
        Builtin Opensuse     tumbleweed             Synced miniwsl.opensuse.rootfs.tar.gz
        Builtin Ubuntu       kinetic         NotDownloaded miniwsl.ubuntu.rootfs.tar.gz
          Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
        Builtin Opensuse     tumbleweed             Synced opensuse.rootfs.tar.gz
          Local Out          unknown                Synced out.rootfs.tar.gz
          Local Postgres     unknown                Synced postgres.rootfs.tar.gz
        Builtin Ubuntu       kinetic                Synced ubuntu.rootfs.tar.gz        
        Get all WSL root filesystem.

    .EXAMPLE
        Get-WslRootFileSystem -Os alpine
           Type Os           Release                 State Name
           ---- --           -------                 ----- ----
        Builtin Alpine       3.17            NotDownloaded alpine.rootfs.tar.gz
            LXD alpine       3.17                   Synced lxd.alpine_3.17.rootfs.tar.gz
            LXD alpine       edge                   Synced lxd.alpine_edge.rootfs.tar.gz
        Builtin Alpine       3.17                   Synced miniwsl.alpine.rootfs.tar.gz
        Get All Alpine root filesystems.
    .EXAMPLE
        Get-WslRootFileSystem -Type LXD
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        LXD almalinux    8                      Synced lxd.almalinux_8.rootfs.tar.gz
        LXD almalinux    9                      Synced lxd.almalinux_9.rootfs.tar.gz
        LXD alpine       3.17                   Synced lxd.alpine_3.17.rootfs.tar.gz
        LXD alpine       edge                   Synced lxd.alpine_edge.rootfs.tar.gz
        LXD centos       9-Stream               Synced lxd.centos_9-Stream.rootfs.ta...
        LXD opensuse     15.4                   Synced lxd.opensuse_15.4.rootfs.tar.gz
        LXD rockylinux   9                      Synced lxd.rockylinux_9.rootfs.tar.gz
        Get All downloaded LXD root filesystems.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory = $false)]
        [string]$Os,
        [Parameter(Mandatory = $false)]
        [WslRootFileSystemState]$State,
        [Parameter(Mandatory = $false)]
        [WslRootFileSystemType]$Type,
        [Parameter(Mandatory = $false)]
        [switch]$Configured,
        [Parameter(Mandatory = $false)]
        [switch]$Outdated
    )

    process {
        $fses = [WslRootFileSystem]::AllFileSystems()

        if ($PSBoundParameters.ContainsKey("Type")) {
            $fses = $fses | Where-Object {
                $_.Type -eq $Type
            }
        }

        if ($PSBoundParameters.ContainsKey("Os")) {
            $fses = $fses | Where-Object {
                $_.Os -eq $Os
            }
        }

        if ($PSBoundParameters.ContainsKey("State")) {
            $fses = $fses | Where-Object {
                $_.State -eq $State
            }
        }

        if ($PSBoundParameters.ContainsKey("Configured")) {
            $fses = $fses | Where-Object {
                $_.AlreadyConfigured -eq $Configured.IsPresent
            }
        }

        if ($PSBoundParameters.ContainsKey("Outdated")) {
            $fses = $fses | Where-Object {
                $_.Outdated
            }
        }

        if ($Name.Length -gt 0) {
            $fses = $fses | Where-Object {
                foreach ($pattern in $Name) {
                    if ($_.Name -ilike $pattern) {
                        return $true
                    }
                }
                
                return $false
            }
            if ($null -eq $fses) {
                throw [UnknownDistributionException]::new($Name)
            }
        }

        return $fses
    }
}

<#
.SYNOPSIS
Remove a WSL root filesystem from the local disk.

.DESCRIPTION
If the WSL root filesystem in synced, it will remove the tar file and its meta
data from the disk. Builtin root filesystems will still appear as output of 
`Get-WslRootFileSystem`, but their state will be `NotDownloaded`.

.PARAMETER Distribution
The identifier of the distribution. It can be an already known name:
- Arch
- Alpine
- Ubuntu
- Debian

It also can be the URL (https://...) of an existing filesystem or a 
distribution name saved through Export-Wsl.

It can also be a name in the form:

    lxd:<os>:<release> (ex: lxd:rockylinux:9)

In this case, it will fetch the last version the specified image in
https://uk.lxd.images.canonical.com/images. 

.PARAMETER Configured
Whether the root filesystem is already configured. This parameter is relevant
only for Builtin distributions.

.PARAMETER RootFileSystem
The WslRootFileSystem object representing the WSL root filesystem to delete.

.INPUTS
One or more WslRootFileSystem objects representing the WSL root filesystem to 
delete.

.OUTPUTS
The WSLRootFileSytem objects updated.

.EXAMPLE
Remove-WslRootFileSystem alpine -Configured
Removes the builtin configured alpine root filesystem.

.EXAMPLE
New-WslRootFileSystem "lxd:alpine:3.17" | Remove-WslRootFileSystem
Removes the LXD alpine 3.17 root filesystem.

.EXAMPLE
Get-WslRootFilesystem -Type LXD | Remove-WslRootFileSystem
Removes all the LXD root filesystems present locally.

.Link
Get-WslRootFileSystem
New-WslRootFileSystem
#>
Function Remove-WslRootFileSystem {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Distribution,
        [Parameter(ParameterSetName = 'Name', Mandatory = $false)]
        [switch]$Configured,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "RootFileSystem")]
        [WslRootFileSystem[]]$RootFileSystem
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $RootFileSystem = New-WslRootFileSystem $Distribution -Configured:$Configured
        }

        if ($null -ne $RootFileSystem) {
            $RootFileSystem | ForEach-Object {
                if ($_.Delete()) {
                    $_
                }
            }        
        }
    }
}

<#
.SYNOPSIS
Get the list of available LXD based root filesystems.

.DESCRIPTION
This command retrieves the list of available LXD root filesystems from the 
Canonical site: https://uk.lxd.images.canonical.com/streams/v1/index.json


.PARAMETER Name
List of names or wildcard based patterns to select the Os.


.EXAMPLE
Get-LXDRootFileSystem
Retrieve the complete list of LXD root filesystems

.EXAMPLE
 Get-LXDRootFileSystem alma*

Os        Release
--        -------
almalinux 8
almalinux 9

Get all alma based filesystems.

.EXAMPLE
Get-LXDRootFileSystem mint | %{ New-WslRootFileSystem "lxd:$($_.Os):$($_.Release)" }

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
     LXD mint         tara            NotDownloaded lxd.mint_tara.rootfs.tar.gz
     LXD mint         tessa           NotDownloaded lxd.mint_tessa.rootfs.tar.gz
     LXD mint         tina            NotDownloaded lxd.mint_tina.rootfs.tar.gz
     LXD mint         tricia          NotDownloaded lxd.mint_tricia.rootfs.tar.gz
     LXD mint         ulyana          NotDownloaded lxd.mint_ulyana.rootfs.tar.gz
     LXD mint         ulyssa          NotDownloaded lxd.mint_ulyssa.rootfs.tar.gz
     LXD mint         uma             NotDownloaded lxd.mint_uma.rootfs.tar.gz
     LXD mint         una             NotDownloaded lxd.mint_una.rootfs.tar.gz
     LXD mint         vanessa         NotDownloaded lxd.mint_vanessa.rootfs.tar.gz

Get all mint based LXD root filesystems as WslRootFileSystem objects.

#>
function Get-LXDRootFileSystem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name
    )
    
    process {
        $fses = Sync-String "https://uk.lxd.images.canonical.com/streams/v1/index.json" | 
        ConvertFrom-Json | 
        ForEach-Object { $_.index.images.products } | Select-String 'amd64:default$' | 
        ForEach-Object { $_ -replace '^(?<distro>[^:]+):(?<release>[^:]+):.*', '${distro},"${release}"' } | 
        ConvertFrom-Csv -Header Os, Release

        if ($Name.Length -gt 0) {
            $fses = $fses | Where-Object {
                foreach ($pattern in $Name) {
                    if ($_.Os -ilike $pattern) {
                        return $true
                    }
                }
                
                return $false
            }
            if ($null -eq $fses) {
                throw [UnknownDistributionException]::new($Name)
            }
        }

        return $fses
    }
}

Export-ModuleMember New-WslRootFileSystem
Export-ModuleMember Sync-File
Export-ModuleMember Sync-WslRootFileSystem
Export-ModuleMember Get-WslRootFileSystem
Export-ModuleMember Remove-WslRootFileSystem
Export-ModuleMember Get-LXDRootFileSystem
Export-ModuleMember New-WslRootFileSystemHash
Export-ModuleMember Progress
Export-ModuleMember Success
Export-ModuleMember Information
