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

# This function is here to mock the download in unit tests
function Sync-File {
    param(
        [System.Uri]$Url,
        [FileInfo]$File
    )
    Write-Host "####> Downloading $($Url) => $($File.FullName)..."
    (New-Object Net.WebClient).DownloadFile($Url, $File.FullName)
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
        }
        else {
            $this.Url = [System.Uri]$Name
            if ($this.Url.IsAbsoluteUri) {
                $this.LocalFileName = $this.Url.Segments[-1]
                $this.AlreadyConfigured = $Configured
                $this.Os = ($this.LocalFileName -split "[-. ]")[0]
                $this.Type = [WslRootFileSystemType]::Uri
            }
            else {
                $this.Url = $null
                $dist_lower = $Name.ToLower()
                $dist_title = (Get-Culture).TextInfo.ToTitleCase($dist_lower)
            
                $urlKey = 'Url'
                $rootfs_prefix = ''
                if ($true -eq $Configured) { 
                    $urlKey = 'ConfiguredUrl' 
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

        $properties = Get-Content -Path "$($File.FullName).json" -ErrorAction SilentlyContinue | ConvertFrom-Json

        $this.LocalFileName = $File.Name
        $this.State = [WslRootFileSystemState]::Synced

        if (!($null -eq $properties)) {
            $this.Os = $properties.Os
            $this.Release = $properties.Release
            $this.Type = [WslRootFileSystemType]$properties.Type
            $this.State = [WslRootFileSystemState]$properties.State
            $this.AlreadyConfigured = $properties.AlreadyConfigured
            $this.Url = $properties.Url
        }
        else {
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

    [int] CompareTo([object] $obj)
    {
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
            # TODO: Checksums
        } | ConvertTo-Json | Set-Content -Path "$($this.File.FullName).json"
    }

    static [WslRootFileSystem[]] AllFileSystems() {
        $path = [WslRootFileSystem]::BasePath
        $files = $path.GetFiles("*.tar.gz")
        $local =  [WslRootFileSystem[]]( $files | ForEach-Object { [WslRootFileSystem]::new($_) })
    
        $builtin = [WslRootFileSystem]::Distributions.keys | ForEach-Object {
            [WslRootFileSystem]::new($_, $false)
            [WslRootFileSystem]::new($_, $true)
        }
        return ($local + $builtin) | Sort-Object | Get-Unique
    }

    # [string]$OnlineChecksum
    # [void]UpdateOnlineChecksum() {
    # }

    # [string]$LocalChecksum
    # [void]UpdateLocalChecksum() {
    # }

    static [DirectoryInfo]$BasePath = $base_rootfs_directory
    

    [System.Uri]$Url

    [WslRootFileSystemState]$State
    [WslRootFileSystemType]$Type
    
    [bool]$AlreadyConfigured

    [string]$Os
    [string]$Release = "unknown"

    [string]$LocalFileName


    # TODO: Get this from JSON file
    static $Distributions = @{
        Arch     = @{
            Url           = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2022.11.01/archlinux.rootfs.tar.gz'
            ConfiguredUrl = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.arch.rootfs.tar.gz'
            Release       = 'current'
        }
        Alpine   = @{
            Url           = 'https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-minirootfs-3.17.0-x86_64.tar.gz'
            ConfiguredUrl = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz'
            Release       = '3.17'
        }
        Ubuntu   = @{
            Url           = 'https://cloud-images.ubuntu.com/wsl/kinetic/current/ubuntu-kinetic-wsl-amd64-wsl.rootfs.tar.gz'
            ConfiguredUrl = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.arch.rootfs.tar.gz'
            Release       = 'kinetic'
        }
        Debian   = @{
            # This is the root fs used to produce the official Debian slim docker image
            # see https://github.com/docker-library/official-images/blob/master/library/debian
            # see https://github.com/debuerreotype/docker-debian-artifacts
            Url           = "https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/bullseye/rootfs.tar.xz"
            ConfiguredUrl = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.debian.rootfs.tar.gz"
            Release       = 'bullseye'
        }
        OpenSuse = @{
            Url           = "https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz"
            ConfiguredUrl = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.opensuse.rootfs.tar.gz"
            Release       = 'tumbleweed'
        }
    }
    
}

function New-WslRootFileSystem {
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name,
        [Parameter(Position = 1, ParameterSetName = 'Name', Mandatory = $false)]
        [switch]$Configured,
        [Parameter(ParameterSetName = 'Path', ValueFromPipeline = $true, Mandatory = $true)]
        [string]$Path,
        [Parameter(ParameterSetName = 'File', ValueFromPipeline = $true, Mandatory = $true)]
        [FileInfo]$File
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            return [WslRootFileSystem]::new($Name, $Configured)
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
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name,
        [Parameter(ParameterSetName = 'Name', Mandatory = $false)]
        [switch]$Configured,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "RootFileSystem")]
        [WslRootFileSystem[]]$RootFileSystem,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $RootFileSystem = New-WslRootFileSystem $Name -Configured:$Configured
        }

        if ($null -ne $RootFileSystem) {
            $RootFileSystem | ForEach-Object {
                [FileInfo] $dest = $_.File

                If (!([WslRootFileSystem]::BasePath.Exists)) {
                    if ($PSCmdlet.ShouldProcess([WslRootFileSystem]::BasePath.Create(), "Create base path")) {
                        Write-Host "####> Creating rootfs base path [$([WslRootFileSystem]::BasePath)]..."
                        [WslRootFileSystem]::BasePath.Create()
                    }
                }
            
        
                if (!$dest.Exists -Or $true -eq $Force) {
                    if ($PSCmdlet.ShouldProcess($_.Url, "Sync locally")) {
                        try {
                            Sync-File $_.Url $dest
                        }
                        catch [Exception] {
                            throw "Error while loading distro [$($_.OsName)] on $($_.Url): $($_.Exception.Message)"
                            return $null
                        }
                        $_.State = [WslRootFileSystemState]::Synced
                        $_.WriteMetadata()
                    }
                }
                else {
                    Write-Host "####> [$($_.OsName)] Root FS already at [$($dest.FullName)]."
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
        [WslRootFileSystemType]$Type
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

        if ($Name.Length -gt 0) {
            $fses = $fses | Where-Object {
                foreach ($pattern in $Name) {
                    write-host "$($_.Name) <=> $pattern"
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


Export-ModuleMember New-WslRootFileSystem
Export-ModuleMember Sync-File
Export-ModuleMember Sync-WslRootFileSystem
Export-ModuleMember Get-WslRootFileSystem

# Get all file related rootfses -Exclude *.json
# get all builtin rootfses
# union both (filtering out synced)
# apply filters (name, type, state, name of course)
# add delete and update methods and rename
# add method to change metadata
# add checksums
