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


class UnknownDistributionException : System.SystemException {
    UnknownDistributionException([string] $Name) : base("Unknown distribution $Name") {
    }
}

class DistributionAlreadyExistsException: System.SystemException {
    DistributionAlreadyExistsException([string] $Name) : base("Distribution $Name already exists") {
    }
}

if ($IsWindows) {
    $wslPath = "$env:windir\system32\wsl.exe"
    if (-not [System.Environment]::Is64BitProcess) {
        # Allow launching WSL from 32 bit powershell
        $wslPath = "$env:windir\sysnative\wsl.exe"
    }

}
else {
    # If running inside WSL, rely on wsl.exe being in the path.
    $wslPath = "wsl.exe"
}


$module_directory = ([System.IO.FileInfo]$MyInvocation.MyCommand.Path).DirectoryName
$base_wsl_directory = "$env:LOCALAPPDATA\Wsl"
$base_rootfs_directory = "$base_wsl_directory\RootFS"

$distributions = @{
    Arch   = @{
        Url             = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2022.11.01/archlinux.rootfs.tar.gz'
        ConfigureScript = 'configure_arch.sh'
    }
    Alpine = @{
        Url             = 'https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-minirootfs-3.17.0-x86_64.tar.gz'
        ConfigureScript = 'configure_alpine.sh'
    }
    Ubuntu = @{
        Url             = 'https://cloud-images.ubuntu.com/wsl/kinetic/current/ubuntu-kinetic-wsl-amd64-wsl.rootfs.tar.gz'
        ConfigureScript = 'configure_ubuntu.sh'
    }
}


function Get-WslRootFS {
    <#
    .SYNOPSIS
        Retrieves the specified WSL distribution root filesystem.

    .DESCRIPTION
        This command retrieves the specified WSL distribution root file system 
        if it is not already present locally. By default, the root filesystem is
        saved in $env:APPLOCALDATA\Wsl\RootFS.

    .PARAMETER Distribution
        The distribution to get. It can be an already known name:
        - Arch
        - Alpine
        - Ubuntu

        It also can be an URL (https://...) or a distribution name saved through
        Export-Wsl.

    .PARAMETER Destination
        Destination directory where to create the distribution directory. 
        Defaults to $env:APPLOCALDATA\Wsl\RootFS (~\AppData\Local\Wsl\RootFS) 
        by default.

    .PARAMETER Force
        Force download even if the file is already there.

    .INPUTS
        None.

    .OUTPUTS
        The path of the root fs filesystem.

    .EXAMPLE
        Get-WslRootFS Ubuntu
        Get-WslRootFS https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-minirootfs-3.17.0-x86_64.tar.gz
    
    .LINK
        Install-Wsl

    .NOTES
        The command tries to be indempotent. It means that it will try not to
        do an operation that already has been done before.

    #>    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Distribution,
        [string]$Destination = $base_rootfs_directory,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $dist_lower = $Distribution.ToLower()
    $dist_title = (Get-Culture).TextInfo.ToTitleCase($dist_lower)
    $rootfs_file = "$Destination\$dist_lower.rootfs.tar.gz"

    if ($distributions.ContainsKey($dist_title)) {
        $properties = $distributions[$Distribution]
        $RootFSURL = $properties['Url']
    }
    else {
        
        If (test-path -PathType Leaf $rootfs_file) {
            return $rootfs_file
        }
        else {
            $RootFSURL = [System.Uri]$Distribution
            if (!$RootFSURL.IsAbsoluteUri) {
                throw [UnknownDistributionException] $Distribution
            }
            else {
                $rootfs_file = "$Destination\$($RootFSURL.Segments[-1])"
            }
        }
    }

    If (!(test-path -PathType container $Destination)) {
        if ($PSCmdlet.ShouldProcess($Destination, 'Create Wsl root fs destination')) {
            $null = New-Item -ItemType Directory -Path $Destination
        }
    }

    # Donwload the root filesystem
    If (!(test-path $rootfs_file) -Or $true -eq $Force) {
        if ($PSCmdlet.ShouldProcess($rootfs_file, 'Download root fs')) {
            Write-Host "####> Downloading $RootFSURL → $rootfs_file..."
            try {
                (New-Object Net.WebClient).DownloadFile($RootFSURL, $rootfs_file)
            }
            catch [Exception] {
                Write-Error "Error while loading: $($_.Exception.Message)"
                return
            }
        }
    }
    else {
        Write-Host "####> $Distribution Root FS already at [$rootfs_file]."
    }

    return $rootfs_file
}


function Install-Wsl {
    <#
    .SYNOPSIS
        Installs and configure a minimal WSL distribution.

    .DESCRIPTION
        This command performs the following operations:
        - Create a Distribution directory
        - Download the Root Filesystem if needed.
        - Create the WSL distribution.
        - Configure the WSL distribution if needed.

        The distribution is configured as follow:
        - A user named after the name of the distribution (arch, alpine or 
        ubuntu) is set as the default user.
        - zsh with oh-my-zsh is used as shell.
        - `powerlevel10k` is set as the default oh-my-zsh theme.
        - `zsh-autosuggestions` plugin is installed.

    .PARAMETER Name
        The name of the distribution. 

    .PARAMETER Distribution
        The identifier of the distribution. It can be an already known name:
        - Arch
        - Alpine
        - Ubuntu

        It also can be an URL (https://...) or a distribution name saved through
        Export-Wsl.


    .PARAMETER BaseDirectory
        Base directory where to create the distribution directory. Equals to 
        $env:APPLOCALDATA\Wsl (~\AppData\Local\Wsl) by default.

    .PARAMETER SkipConfigure
        Skip Configuration. Only relevant for already known distributions.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Install-Wsl toto
    
    .LINK
        Uninstall-Wsl
        https://github.com/romkatv/powerlevel10k
        https://github.com/zsh-users/zsh-autosuggestions
        https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin

    .NOTES
        The command tries to be indempotent. It means that it will try not to
        do an operation that already has been done before.

    #>    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name,
        [string]$Distribution = 'Alpine',
        [string]$BaseDirectory = $base_wsl_directory,
        [Parameter(Mandatory = $false)]
        [switch]$SkipConfigure
    )

    # Retrieve the distribution if it already exists
    $current_distribution = Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name }

    if ($null -ne $current_distribution) {
        throw [DistributionAlreadyExistsException] $Name
    }

    If (!(test-path -PathType container $BaseDirectory)) {
        if ($PSCmdlet.ShouldProcess($BaseDirectory, 'Create Wsl base directory')) {
            $null = New-Item -ItemType Directory -Path $BaseDirectory
        }
    }

    # Where to install the distribution
    $distribution_dir = "$BaseDirectory\$Name"

    # Create the directory
    If (!(test-path $distribution_dir)) {
        Write-Host "####> Creating directory [$distribution_dir]..."
        $null = New-Item -ItemType Directory -Force -Path $distribution_dir
    }
    else {
        Write-Host "####> Distribution directory [$distribution_dir] already exists."
    }

    # Get the root fs file locally
    $rootfs_file = Get-WslRootFS $Distribution

    Write-Host "####> Creating distribution [$Name]..."
    if ($PSCmdlet.ShouldProcess($Name, 'Create distribution')) {
        &$wslPath --import $Name $distribution_dir $rootfs_file | Write-Verbose
    }

    if ($false -eq $SkipConfigure) {
        $configure_script = "configure_$($Distribution.ToLower()).sh"
        if (Test-Path -PathType Leaf "$module_directory\$configure_script") {
            if ($PSCmdlet.ShouldProcess($Name, 'Configure distribution')) {
                Write-Host "####> Running initialization script [$configure_script] on distribution [$Name]..."
                Push-Location "$module_directory"
                &$wslPath -d $Name -u root ./$configure_script 2>&1 | Write-Verbose
                Pop-Location
        
                Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name } | Set-ItemProperty -Name DefaultUid -Value 1000
            }
        }
    }

    Write-Host "####> Done. Command to enter distribution: wsl -d $Name"
    ## More Stuff ?
    # To import your publick keys and use the yubikey for signing.
    #  gpg --keyserver keys.openpgp.org --search antoine@mrtn.fr
}

function Uninstall-Wsl {
    <#
    .SYNOPSIS
        Uninstalls Arch Linux based WSL distribution.

    .DESCRIPTION
        This command unregisters the specified distribution. It also deletes the
        distribution base root filesystem and the directory of the distribution.

    .PARAMETER Name
        The name of the distribution. If ommitted, will take WslArch by
        default.
    
    .PARAMETER KeepDirectory
        If specified, keep the distribution directory. This allows recreating
        the distribution from a saved root file system.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Uninstall-Wsl toto
    
    .LINK
        Install-Wsl
        https://github.com/romkatv/powerlevel10k
        https://github.com/zsh-users/zsh-autosuggestions
        https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin

    .NOTES
        The command tries to be indempotent. It means that it will try not to
        do an operation that already has been done before.

    #>    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name,
        [Parameter(Mandatory = $false)]
        [switch]$KeepDirectory
    )

    # Retrieve the distribution if it already exists
    $current_distribution = Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name }
    if ($null -eq $current_distribution) {
        throw [UnknownDistributionException] $Name
    }

    # Where to install the distribution
    $distribution_dir = $current_distribution.GetValue('BasePath')

    if ($PSCmdlet.ShouldProcess($Name, 'Unregister distribution')) {
        Write-Verbose "Unregistering WSL distribution $Name"
        &$wslPath --unregister $Name 2>&1 | Write-Verbose 
    }
    if ($false -eq $KeepDirectory) {
        Remove-Item -Path $distribution_dir -Recurse
    }
}

function Export-Wsl {
    <#
    .SYNOPSIS
        Exports the file system of an Arch Linux WSL distrubtion.

    .DESCRIPTION
        This command exports the distribution and tries to compress it with 
        the `gzip` command embedded in the distribution. If no destination file
        is given, it replaces the root filesystem file in the distribution 
        directory.

    .PARAMETER Name
        The name of the distribution. If ommitted, will take WslArch by
        default.

    .PARAMETER OutputName
        Name of the output distribution. By default, uses the name of the 
        distribution.
    
    .PARAMETER Destination
        Base directory where to save the root file system. Equals to 
        $env:APPLOCALDAT\Wsl\RootFS (~\AppData\Local\Wsl\RootFS) by default.

    .PARAMETER OutputFile
        The name of the output file. If it is not specified, it will overwrite
        the root file system of the distribution.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        Install-Wsl toto
        wsl -d toto -u root apk add openrc docker
        Export-Wsl toto docker

        Uninstall-Wsl toto
        Install-Wsl toto -Distribution docker
    
    .LINK
        Install-Wsl
        https://github.com/romkatv/powerlevel10k
        https://github.com/zsh-users/zsh-autosuggestions
        https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin

    .NOTES
        The command tries to be indempotent. It means that it will try not to
        do an operation that already has been done before.

    #>    
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name,
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$OutputName,
        [string]$Destination = $base_rootfs_directory,
        [Parameter(Mandatory = $false)]
        [string]$OutputFile
    )

    # Retrieve the distribution if it already exists
    $current_distribution = Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name }
    if ($null -eq $current_distribution) {
        throw [UnknownDistributionException] $Name
    }

    if ($OutputFile.Length -eq 0) {
        if ($OutputName.Length -eq 0) {
            $OutputName = $Name
        }
        $OutputFile = "$Destination\$OutputName.rootfs.tar.gz"
        If (!(test-path -PathType container $Destination)) {
            if ($PSCmdlet.ShouldProcess($Destination, 'Create Wsl base directory')) {
                $null = New-Item -ItemType Directory -Path $Destination
            }
        }
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Export distribution')) {


        $export_file = $OutputFile -replace '\.gz$'

        Write-Host "####> Exporting WSL distribution $Name to $export_file..."
        &$wslPath --export $Name "$export_file" | Write-Verbose
        $file_item = Get-Item -Path "$export_file"
        $filepath = $file_item.Directory.FullName
        Write-Host "####> Compressing $export_file to $OutputFile..."
        Remove-Item "$OutputFile" -Force -ErrorAction SilentlyContinue
        &$wslPath -d $Name --cd "$filepath" gzip $file_item.Name | Write-Verbose

        Write-Host "####> Distribution $Name saved to $OutputFile."
    }
}

Export-ModuleMember Install-Wsl
Export-ModuleMember Uninstall-Wsl
Export-ModuleMember Export-Wsl
Export-ModuleMember Get-WslRootFS
