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

# Cache the distributions data at script level
$script:Distributions = Import-PowerShellDataFile "$PSScriptRoot\Distributions.psd1"


# The base URLs for Incus images
$base_incus_url = "https://images.linuxcontainers.org/images"
# We don't support ARM yet
$incus_directory_suffix = "amd64/default"
$incus_rootfs_name = "rootfs.tar.xz"
$base_wsl_directory = "$env:LOCALAPPDATA\Wsl"
$base_rootfs_directory = [DirectoryInfo]::new("$base_wsl_directory\RootFS")


class UnknownIncusDistributionException : System.SystemException {
    UnknownIncusDistributionException([string] $Os, [string]$Release) : base("Unknown Incus distribution with OS $Os and Release $Release. Check $base_incus_url.") {
    }
}

<#
.SYNOPSIS
Returns the URL of the root filesystem of the Incus image for the specified OS
and Release.

.DESCRIPTION
Incus images made by canonical (https://images.linuxcontainers.org/images) are
"rolling". In Consequence, getting the current root filesystem URL for a distro
Involves browsing the distro directory to get the directory name of the last
build.

.PARAMETER Os
Parameter The name of the OS (debian, ubuntu, alpine, rockylinux, centos, ...)

.PARAMETER Release
The release (version). Highly dependent on the distro. For rolling release
distributions (e.g. Arch), use `current`.

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

    $url = "$base_incus_url/$Os/$Release/$incus_directory_suffix"

    try {
        $last_release_directory = (Invoke-WebRequest $url).Links | Select-Object -Last 1 -ExpandProperty "href"
    }
    catch {
        throw [UnknownIncusDistributionException]::new($OS, $Release)
    }


    return [System.Uri]"$url/$last_release_directory$incus_rootfs_name"
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
        if ($this.Url.Scheme -ne 'docker') {
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
    }

    [string]GetExpectedHash([System.Uri]$Uri) {
        if ($this.Url.Scheme -eq 'docker') {
            $Registry = $Uri.Host
            $Repository = $Uri.AbsolutePath.Trim('/')
            $authToken = Get-DockerAuthToken -Registry $Registry -Repository $Repository
            $layer = Get-DockerImageLayerManifest -Registry $Registry -Image $Repository -Tag $Uri.Fragment.TrimStart('#') -AuthToken $authToken
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
            return $null
        }
        $temp = [FileInfo]::new($Destination.FullName + '.tmp')

        try {
            if ($Uri.Scheme -eq 'docker') {
                # TODO: Handle docker case
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

    [void] init([string]$Name, [bool]$Configured) {

        # Get the root fs file locally
        if ($Name -match '^incus:(?<Os>[^:]+):(?<Release>[^:]+)$') {
            $this.Type = [WslRootFileSystemType]::Incus
            $this.Os = $Matches.Os
            $this.Release = $Matches.Release
            $this.Url = Get-LxdRootFSUrl -Os:$this.Os -Release:$this.Release
            $this.AlreadyConfigured = $Configured
            $this.LocalFileName = "incus.$($this.Os)_$($this.Release).rootfs.tar.gz"
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

                $distributions = $script:Distributions
                if ($distributions.ContainsKey($dist_title)) {
                    $properties = $distributions[$dist_title]
                    if (!$properties.ContainsKey($urlKey)) {
                        throw "No configured Root filesystem for $dist_title."
                    }
                    $this.Os = $dist_title
                    $this.Url = [System.Uri]$properties[$urlKey]
                    $this.AlreadyConfigured = $Configured
                    $this.Type = [WslRootFileSystemType]::Builtin
                    $this.Release = $properties['Release']
                    $this.HashSource = [PSCustomObject]$properties[$hashKey]
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

        $distributions = $script:Distributions

        if (!($this.ReadMetaData())) {
            $name = $File.Name -replace '\.rootfs\.tar\.gz$', ''
            if ($name.StartsWith("miniwsl.")) {
                $this.AlreadyConfigured = $true
                $this.Type = [WslRootFileSystemType]::Builtin
                $name = (Get-Culture).TextInfo.ToTitleCase(($name -replace 'miniwsl\.', ''))
                $this.Os = $name
                $this.Release = $distributions[$name]['Release']
                $this.Url = $distributions[$name]['ConfiguredUrl']
            }
            elseif ($name.StartsWith("incus.")) {
                $this.AlreadyConfigured = $false
                $this.Type = [WslRootFileSystemType]::Incus
                $this.Os, $this.Release = ($name -replace 'incus\.', '') -Split '_'
                $this.Url = Get-LxdRootFSUrl -Os $this.Os -Release $this.Release
            }
            else {
                $name = (Get-Culture).TextInfo.ToTitleCase($name)
                $this.Os = $name
                if ($distributions.ContainsKey($name)) {
                    $this.AlreadyConfigured = $false
                    $this.Type = [WslRootFileSystemType]::Builtin
                    $this.Release = $distributions[$name]['Release']
                    $this.Url = $distributions[$name]['Url']
                }
                else {
                    # Ensure we have a tar.gz file
                    $this.Type = [WslRootFileSystemType]::Local
                    $this.AlreadyConfigured = $false
                    $this.Url = [System.Uri]::new($File.FullName).AbsoluteUri

                    if ($this.LocalFileName -notmatch '\.tar(\.gz)?$') {
                        $this.Os = $name
                        $this.Release = "unknown"
                    } else {

                        try {
                            # Get os-release from the tar.gz file
                            $osRelease = tar -xOf $File.FullName etc/os-release usr/lib/os-release
                            if ($LASTEXITCODE -ne 0) {
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
                            $this.Os = $name
                            $this.Release = "unknown"
                        }
                    }


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

        $builtin = $script:Distributions.Keys | ForEach-Object {
            [WslRootFileSystem]::new($_, $false)
            [WslRootFileSystem]::new($_, $true)
        }
        return ($local + $builtin) | Sort-Object | Get-Unique
    }

    [WslRootFileSystemHash]GetHashSource() {
        if ($this.Type -eq [WslRootFileSystemType]::Local -and $null -ne $this.Url) {
            $source = [WslRootFileSystemHash]::new()
            $source.Algorithm = 'SHA256'
            $source.Type = 'sums'
            $source.Mandatory = $false
            return $source
        } elseif ($this.HashSource) {
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
New-WslRootFileSystemHash https://cloud-images.ubuntu.com/wsl/noble/current/SHA256SUMS
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

        incus:<os>:<release> (ex: incus:rockylinux:9)

    In this case, it will fetch the last version the specified image in
    https://images.linuxcontainers.org/images.

    .PARAMETER Configured
    Whether the distribution is configured. This parameter is relevant for Builtin
    distributions.

    .PARAMETER Path
    The path of the root filesystem. Should be a file ending with `rootfs.tar.gz`.
    It will try to extract the OS and Release from the filename (in /etc/os-release).

    .PARAMETER File
    A FileInfo object of the compressed root filesystem.

    .EXAMPLE
    New-WslRootFileSystem incus:alpine:3.19
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    The WSL root filesystem representing the incus alpine 3.19 image.

    .EXAMPLE
    New-WslRootFileSystem alpine -Configured
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    The builtin configured Alpine root filesystem.

    .EXAMPLE
    New-WslRootFileSystem test.rootfs.tar.gz
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.21.3                   Synced test.rootfs.tar.gz
    The The root filesystem from the file.

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
                $Path = Resolve-Path $Path
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

        incus:<os>:<release> (ex: incus:rockylinux:9)

    In this case, it will fetch the last version the specified image in
    https://images.linuxcontainers.org/images.

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
    The path of the WSL root filesystem. It is suitable as input for the
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
        [Parameter(Mandatory = $true, ParameterSetName = "Path")]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $RootFileSystem = New-WslRootFileSystem $Distribution -Configured:$Configured
        }
        if ($PSCmdlet.ParameterSetName -eq "Path") {
            $RootFileSystem = New-WslRootFileSystem -Path $Path
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
        This can be the ones already synchronized as well as the Builtin filesystems available.
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
        Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
        Builtin Arch         current                Synced arch.rootfs.tar.gz
        Builtin Debian       bookworm               Synced debian.rootfs.tar.gz
          Local Docker       unknown                Synced docker.rootfs.tar.gz
          Local Flatcar      unknown                Synced flatcar.rootfs.tar.gz
            Incus almalinux    8                      Synced incus.almalinux_8.rootfs.tar.gz
            Incus almalinux    9                      Synced incus.almalinux_9.rootfs.tar.gz
            Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
            Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
            Incus centos       9-Stream               Synced incus.centos_9-Stream.rootfs.ta...
            Incus opensuse     15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
            Incus rockylinux   9                      Synced incus.rockylinux_9.rootfs.tar.gz
        Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
        Builtin Arch         current                Synced miniwsl.arch.rootfs.tar.gz
        Builtin Debian       bookworm               Synced miniwsl.debian.rootfs.tar.gz
        Builtin Opensuse     tumbleweed             Synced miniwsl.opensuse.rootfs.tar.gz
        Builtin Ubuntu       noble         NotDownloaded miniwsl.ubuntu.rootfs.tar.gz
          Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
        Builtin Opensuse     tumbleweed             Synced opensuse.rootfs.tar.gz
          Local Out          unknown                Synced out.rootfs.tar.gz
          Local Postgres     unknown                Synced postgres.rootfs.tar.gz
        Builtin Ubuntu       noble                Synced ubuntu.rootfs.tar.gz
        Get all WSL root filesystem.

    .EXAMPLE
        Get-WslRootFileSystem -Os alpine
           Type Os           Release                 State Name
           ---- --           -------                 ----- ----
        Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
            Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
            Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
        Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
        Get All Alpine root filesystems.
    .EXAMPLE
        Get-WslRootFileSystem -Type Incus
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        Incus almalinux    8                      Synced incus.almalinux_8.rootfs.tar.gz
        Incus almalinux    9                      Synced incus.almalinux_9.rootfs.tar.gz
        Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
        Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
        Incus centos       9-Stream               Synced incus.centos_9-Stream.rootfs.ta...
        Incus opensuse     15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
        Incus rockylinux   9                      Synced incus.rockylinux_9.rootfs.tar.gz
        Get All downloaded Incus root filesystems.
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
        $fileSystems = [WslRootFileSystem]::AllFileSystems()

        if ($PSBoundParameters.ContainsKey("Type")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.Type -eq $Type
            }
        }

        if ($PSBoundParameters.ContainsKey("Os")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.Os -eq $Os
            }
        }

        if ($PSBoundParameters.ContainsKey("State")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.State -eq $State
            }
        }

        if ($PSBoundParameters.ContainsKey("Configured")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.AlreadyConfigured -eq $Configured.IsPresent
            }
        }

        if ($PSBoundParameters.ContainsKey("Outdated")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.Outdated
            }
        }

        if ($Name.Length -gt 0) {
            $fileSystems = $fileSystems | Where-Object {
                foreach ($pattern in $Name) {
                    if ($_.Name -ilike $pattern) {
                        return $true
                    }
                }

                return $false
            }
            if ($null -eq $fileSystems) {
                throw [UnknownDistributionException]::new($Name)
            }
        }

        return $fileSystems
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

    incus:<os>:<release> (ex: incus:rockylinux:9)

In this case, it will fetch the last version the specified image in
https://images.linuxcontainers.org/images.

.PARAMETER Configured
Whether the root filesystem is already configured. This parameter is relevant
only for Builtin distributions.

.PARAMETER RootFileSystem
The WslRootFileSystem object representing the WSL root filesystem to delete.

.INPUTS
One or more WslRootFileSystem objects representing the WSL root filesystem to
delete.

.OUTPUTS
The WSLRootFileSystem objects updated.

.EXAMPLE
Remove-WslRootFileSystem alpine -Configured
Removes the builtin configured alpine root filesystem.

.EXAMPLE
New-WslRootFileSystem "incus:alpine:3.19" | Remove-WslRootFileSystem
Removes the Incus alpine 3.19 root filesystem.

.EXAMPLE
Get-WslRootFilesystem -Type Incus | Remove-WslRootFileSystem
Removes all the Incus root filesystems present locally.

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
Get the list of available Incus based root filesystems.

.DESCRIPTION
This command retrieves the list of available Incus root filesystems from the
Canonical site: https://images.linuxcontainers.org/imagesstreams/v1/index.json


.PARAMETER Name
List of names or wildcard based patterns to select the Os.


.EXAMPLE
Get-IncusRootFileSystem
Retrieve the complete list of Incus root filesystems

.EXAMPLE
 Get-IncusRootFileSystem alma*

Os        Release
--        -------
almalinux 8
almalinux 9

Get all alma based filesystems.

.EXAMPLE
Get-IncusRootFileSystem mint | %{ New-WslRootFileSystem "incus:$($_.Os):$($_.Release)" }

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
     Incus mint         tara            NotDownloaded incus.mint_tara.rootfs.tar.gz
     Incus mint         tessa           NotDownloaded incus.mint_tessa.rootfs.tar.gz
     Incus mint         tina            NotDownloaded incus.mint_tina.rootfs.tar.gz
     Incus mint         tricia          NotDownloaded incus.mint_tricia.rootfs.tar.gz
     Incus mint         ulyana          NotDownloaded incus.mint_ulyana.rootfs.tar.gz
     Incus mint         ulyssa          NotDownloaded incus.mint_ulyssa.rootfs.tar.gz
     Incus mint         uma             NotDownloaded incus.mint_uma.rootfs.tar.gz
     Incus mint         una             NotDownloaded incus.mint_una.rootfs.tar.gz
     Incus mint         vanessa         NotDownloaded incus.mint_vanessa.rootfs.tar.gz

Get all mint based Incus root filesystems as WslRootFileSystem objects.

#>
function Get-IncusRootFileSystem {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name
    )

    process {
        $fileSystems = Sync-String "https://images.linuxcontainers.org/streams/v1/index.json" |
        ConvertFrom-Json |
        ForEach-Object { $_.index.images.products } | Select-String 'amd64:default$' |
        ForEach-Object { $_ -replace '^(?<distro>[^:]+):(?<release>[^:]+):.*', '${distro},"${release}"' } |
        ConvertFrom-Csv -Header Os, Release

        if ($Name.Length -gt 0) {
            $fileSystems = $fileSystems | Where-Object {
                foreach ($pattern in $Name) {
                    if ($_.Os -ilike $pattern) {
                        return $true
                    }
                }

                return $false
            }
            if ($null -eq $fileSystems) {
                throw [UnknownDistributionException]::new($Name)
            }
        }

        return $fileSystems
    }
}

# Internal function to get user agent
function Get-UserAgentString {
    return "Wsl-Manager/1.0 (+https://mrtn.me/PowerShell-Wsl-Manager/) PowerShell/$($PSVersionTable.PSVersion.Major).$($PSVersionTable.PSVersion.Minor) (Windows NT $([System.Environment]::OSVersion.Version.Major).$([System.Environment]::OSVersion.Version.Minor); $(if(${env:ProgramFiles(Arm)}){'ARM64; '}elseif($env:PROCESSOR_ARCHITECTURE -eq 'AMD64'){'Win64; x64; '})$(if($env:PROCESSOR_ARCHITEW6432 -in 'AMD64','ARM64'){'WOW64; '})$PSEdition)"
}

# Internal function to get authentication token
function Get-DockerAuthToken {
    param(
        [string]$Registry,
        [string]$Repository
    )

    try {
        Progress "Getting docker authentication token for registry $Registry and repository $Repository..."
        $tokenUrl = "https://$Registry/token?service=$Registry&scope=repository:$Repository`:pull"

        $tokenWebClient = New-Object System.Net.WebClient
        $tokenWebClient.Headers.Add("User-Agent", (Get-UserAgentString))

        $tokenResponse = $tokenWebClient.DownloadString($tokenUrl)
        $tokenData = $tokenResponse | ConvertFrom-Json

        if ($tokenData.token) {
            return $tokenData.token
        }
        else {
            throw "No token received from authentication endpoint"
        }
    }
    catch {
        throw "Failed to get authentication token: $($_.Exception.Message)"
    }
    finally {
        if ($tokenWebClient) {
            $tokenWebClient.Dispose()
        }
    }
}

function Get-DockerImageLayerManifest {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$AuthToken,

        [Parameter(Mandatory = $true)]
        [string]$ImageName,

        [Parameter(Mandatory = $true)]
        [string]$Tag,

        [Parameter(Mandatory = $false)]
        [string]$Registry = "ghcr.io"

        )

        # Create WebClient with proper headers
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("User-Agent", (Get-UserAgentString))
        # $webClient.Headers.Add("Accept", "application/vnd.docker.distribution.manifest.v2+json")
        $webClient.Headers.Add("Accept", "application/vnd.oci.image.index.v1+json")
        $webClient.Headers.Add("Authorization", "Bearer $AuthToken")

        # Step 1: Get the image manifest
        $manifestUrl = "https://$Registry/v2/$ImageName/manifests/$Tag"
        Progress "Getting image manifests from $manifestUrl..."

        try {
            $manifestJson = $webClient.DownloadString($manifestUrl)
            $manifest = $manifestJson | ConvertFrom-Json
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response.StatusCode -eq 401) {
                throw "Access denied to registry. The image may not exist or authentication failed."
            }
            elseif ($_.Exception.Response.StatusCode -eq 404) {
                throw "Image not found: $fullImageName`:$Tag"
            }
            else {
                throw "Failed to get manifest: $($_.Exception.Message)"
            }
        }

        # Step 2: Extract the amd manifest information
        if (-not $manifest.manifests -or $manifest.manifests.Count -eq 0) {
            throw "No manifests found in the image manifest"
        }

        $amdManifest = $manifest.manifests | Where-Object { $_.platform.architecture -eq 'amd64' }
        if (-not $amdManifest) {
            throw "No amd64 manifest found in the image manifest"
        }

        # replace the Accept header
        $webClient.Headers.Remove("Accept")
        $webClient.Headers.Add("Accept", $amdManifest.mediaType)

        $manifestUrl = "https://$Registry/v2/$ImageName/manifests/$($amdManifest.digest)"

        Progress "Getting image manifest from $manifestUrl..."

        try {
            $manifestJson = $webClient.DownloadString($manifestUrl)
            $manifest = $manifestJson | ConvertFrom-Json
        }
        catch [System.Net.WebException] {
            if ($_.Exception.Response.StatusCode -eq 401) {
                throw "Access denied to registry. The image may not exist or authentication failed."
            }
            elseif ($_.Exception.Response.StatusCode -eq 404) {
                throw "Image not found: $fullImageName`:$Tag"
            }
            else {
                throw "Failed to get manifest: $($_.Exception.Message)"
            }
        }

        # Step 2: Extract layer information
        if (-not $manifest.layers -or $manifest.layers.Count -ne 1) {
            throw "The image should have exactly one layer"
        }

        Information "Found $($manifest.layers.Count) layer(s) in the image"

        # For images built FROM scratch with ADD, we expect typically one layer
        # Take the first (and usually only) layer
        $layer = $manifest.layers[0]

        return $layer
}

<#
.SYNOPSIS
Downloads a Docker image layer from GitHub Container Registry (ghcr.io) as a tar.gz file.

.DESCRIPTION
This function downloads a Docker image from GitHub Container Registry by making HTTP requests to:
1. Get the image manifest
2. Ensure the image contains only one layer
3. Download the layer blob
4. Save it as a tar.gz file locally

This is specifically designed to work with images built by the build-rootfs-oci.yaml workflow,
which creates images with a single layer containing the root filesystem.

.PARAMETER ImageName
The name of the Docker image (e.g., "antoinemartin/powershell-wsl-manager/miniwsl-alpine")

.PARAMETER Tag
The tag of the image (e.g., "latest", "3.19.1", "2025.08.01")

.PARAMETER DestinationFile
The path where the downloaded layer should be saved as a tar.gz file

.PARAMETER Registry
The container registry URL. Defaults to "ghcr.io"

.EXAMPLE
Get-DockerImageLayer -ImageName "antoinemartin/powershell-wsl-manager/miniwsl-alpine" -Tag "latest" -DestinationFile "alpine.rootfs.tar.gz"
Downloads the latest alpine miniwsl image layer to alpine.rootfs.tar.gz

.EXAMPLE
Get-DockerImageLayer -ImageName "antoinemartin/powershell-wsl-manager/miniwsl-arch" -Tag "2025.08.01" -DestinationFile "arch.rootfs.tar.gz"
Downloads the arch miniwsl image with specific version tag

.NOTES
This function requires network access to the GitHub Container Registry.
The function assumes the Docker image has only one layer (typical for FROM scratch images with ADD).
#>
function Get-DockerImageLayer {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$ImageName,

        [Parameter(Mandatory = $true)]
        [string]$Tag,

        [Parameter(Mandatory = $true)]
        [string]$DestinationFile,

        [Parameter(Mandatory = $false)]
        [string]$Registry = "ghcr.io"
    )

    # Internal function to format file size
    function Format-FileSize {
        param([long]$Bytes)

        if ($null -eq $Bytes) { $Bytes = 0 }

        $gb = [math]::pow(2, 30)
        $mb = [math]::pow(2, 20)
        $kb = [math]::pow(2, 10)

        if ($Bytes -gt $gb) {
            "{0:n1} GB" -f ($Bytes / $gb)
        }
        elseif ($Bytes -gt $mb) {
            "{0:n1} MB" -f ($Bytes / $mb)
        }
        elseif ($Bytes -gt $kb) {
            "{0:n1} KB" -f ($Bytes / $kb)
        }
        else {
            "$Bytes B"
        }
    }

    try {
        $fullImageName = "$Registry/$ImageName"
        Progress "Downloading Docker image layer from $fullImageName`:$Tag..."

        # Get authentication token
        $authToken = Get-DockerAuthToken -Registry $Registry -Repository $ImageName
        Information "Authentication token acquired"

        $layer = Get-DockerImageLayerManifest -Registry $Registry -ImageName $ImageName -Tag $Tag -AuthToken $authToken

        # Ensure the image contains only one layer
        if ($layer.Count -ne 1) {
            throw "The image [$($ImageName):$Tag] contains more than one layer. Only single-layer images are supported."
        }

        $layerDigest = $layer.digest
        $layerSize = $layer.size

        Information "Layer digest: $layerDigest"
        Information "Layer size: $(Format-FileSize $layerSize)"

        # Step 3: Download the layer blob
        $blobUrl = "https://$Registry/v2/$ImageName/blobs/$layerDigest"
        Progress "Downloading layer blob from $blobUrl..."

        # Prepare destination file
        $destinationFileInfo = [System.IO.FileInfo]::new($DestinationFile)

        # Ensure destination directory exists
        if (-not $destinationFileInfo.Directory.Exists) {
            $destinationFileInfo.Directory.Create()
        }

        # Download the blob with authentication
        $webClient = New-Object System.Net.WebClient
        $webClient.Headers.Add("Authorization", "Bearer $authToken")
        $webClient.Headers.Add("User-Agent", (Get-UserAgentString))
        $webClient.DownloadFile($blobUrl, $destinationFileInfo.FullName)

        Success "Successfully downloaded Docker image layer to $($destinationFileInfo.FullName)"

        # Verify the file was created and has content
        if ($destinationFileInfo.Exists) {
            $destinationFileInfo.Refresh()
            Information "Downloaded file size: $(Format-FileSize $destinationFileInfo.Length)"

            # Check file integrity (e.g., hash)
            $expectedHash = $layer.digest -split ":" | Select-Object -Last 1
            # $actualHash = Get-FileHash -Path $destinationFileInfo.FullName -Algorithm SHA256 | Select-Object -ExpandProperty Hash
            # if ($expectedHash -ne $actualHash) {
            #     throw "Downloaded file hash does not match expected hash. Expected: $expectedHash, Actual: $actualHash"
            # }
            return $expectedHash
        }
        else {
            throw "Failed to create destination file: $DestinationFile"
        }

    }
    catch {
        Write-Error "Failed to download Docker image layer: $($_.Exception.Message)"
        throw
    }
    finally {
        if ($webClient) {
            $webClient.Dispose()
        }
    }
}



Export-ModuleMember New-WslRootFileSystem
Export-ModuleMember Sync-File
Export-ModuleMember Sync-WslRootFileSystem
Export-ModuleMember Get-WslRootFileSystem
Export-ModuleMember Remove-WslRootFileSystem
Export-ModuleMember Get-IncusRootFileSystem
Export-ModuleMember New-WslRootFileSystemHash
Export-ModuleMember Get-DockerImageLayer
Export-ModuleMember Progress
Export-ModuleMember Success
Export-ModuleMember Information

# Define the types to export with type accelerators.
# Note: Unlike the `using module` approach, this approach allows
#       you to *selectively* export `class`es and `enum`s.
$exportableTypes = @(
  [WslRootFileSystem]
)

# Get the non-public TypeAccelerators class for defining new accelerators.
$typeAcceleratorsClass = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')

# Add type accelerators for every exportable type.
$existingTypeAccelerators = $typeAcceleratorsClass::Get
foreach ($type in $exportableTypes) {
  # !! $TypeAcceleratorsClass::Add() quietly ignores attempts to redefine existing
  # !! accelerators with different target types, so we check explicitly.
  $existing = $existingTypeAccelerators[$type.FullName]
  if ($null -ne $existing -and $existing -ne $type) {
    throw "Unable to register type accelerator [$($type.FullName)], because it is already defined with a different type ([$existing])."
  }
  $typeAcceleratorsClass::Add($type.FullName, $type)
}
