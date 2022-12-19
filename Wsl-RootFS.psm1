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


class WslRootFileSystem {
    [void] init([string]$Name, [bool]$Configured) {
        $this | Add-Member -Name IsLocalOnly -Type ScriptProperty -Value {
            return ($null -eq $this.Url)
        }

        $this | Add-Member -Name Name -Type ScriptProperty -Value {
            return "$($this.Os):$($this.Release)"
        }

        $this | Add-Member -Name File -Type ScriptProperty -Value {
            return [FileInfo]::new([Path]::Combine([WslRootFileSystem]::BasePath, $this.LocalFileName))
        }

        $this | Add-Member -Name IsAvailableLocally -Type ScriptProperty -Value {
            return $this.File.Exists
        }

        $defaultDisplaySet = "Os", "Release", "Type", "State"

        #Create the default property display set
        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet", [string[]]$defaultDisplaySet)
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
        $this | Add-Member MemberSet PSStandardMembers $PSStandardMembers


        # Get the root fs file locally
        if ($Name -match '^lxd:(?<Os>[^:]+):(?<Release>[^:]+)$') {
            $this.Type = [WslRootFileSystemType]::LXD
            $this.Os = $Matches.Os
            $this.Release = $Matches.Release
            $this.Url = Get-LxdRootFSUrl -Os:$this.Os -Release:$this.Release
            $this.AlreadyConfigured = $false
            $this.LocalFileName = "lxd.$($this.Os)_$($this.Release).rootfs.tar.gz"
        }
        else {
            $this.Url = [System.Uri]$Name
            if ($this.Url.IsAbsoluteUri) {
                $this.LocalFileName = $this.Url.Segments[-1]
                $this.AlreadyConfigured = $false
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

    [string] ToString() {
        return $this.Name
    }

    [string] Sync([bool]$Force) {
        [FileInfo] $dest = $this.File

        if (!$dest.Exists -Or $true -eq $Force) {
            Write-Host "####> [$($this.Name)] Downloading $($this.Url) => $($dest.FullName)..."
            try {
                (New-Object Net.WebClient).DownloadFile($this.Url, $dest.FullName)
            }
            catch [Exception] {
                throw "Error while loading distro [$($this.Name)] on $($this.Url): $($_.Exception.Message)"
                return $null
            }
        }
        else {
            Write-Host "####> [$($this.Name)] Root FS already at [$($dest.FullName)]."
        }
    
        return $dest.FullName
    }

    # [string]$OnlineChecksum
    # [void]UpdateOnlineChecksum() {
    # }

    # [string]$LocalChecksum
    # [void]UpdateLocalChecksum() {
    # }

    static [FileSystemInfo]$BasePath = $base_rootfs_directory
    

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
            ConfiguredUrl = ' https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz'
            Release       = '3.17'
        }
        Ubuntu   = @{
            Url           = 'https://cloud-images.ubuntu.com/wsl/kinetic/current/ubuntu-kinetic-wsl-amd64-wsl.rootfs.tar.gz'
            ConfiguredUrl = ' https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.arch.rootfs.tar.gz'
            Release       = 'kinetic'
        }
        Debian   = @{
            Url     = Get-LxdRootFSUrl "debian" "bullseye"
            Release = 'bullseye'
        }
        OpenSuse = @{
            Url           = "https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz"
            ConfiguredUrl = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.opensuse.rootfs.tar.gz"
            Release       = 'tumbleweed'
        }
    }
    
}

function New-WslRootFileSystem {
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name,
        [Parameter(Position = 1, Mandatory = $false)]
        [bool]$Configured = $false
    )

    return [WslRootFileSystem]::new($Name, $Configured)
}

# Export-ModuleMember New-WslRootFileSystem
# Export-ModuleMember Get-LxdRootFSUrl
