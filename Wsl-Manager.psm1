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

$distributions = @{
    Arch   = @{
        Url             = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/22.11.01/archlinux.rootfs.tar.gz'
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



function Install-Wsl {
    <#
    .SYNOPSIS
        Installs and configure a minimal Arch Linux based WSL distribution.

    .DESCRIPTION
        This command performs the following operations:
        - Create a Distribution directory
        - Download the Root Filesystem.
        - Create the WSL distribution.
        - Configure the WSL distribution.

        The distribution is configured as follow:
        - A user named `arch` is set as the default user.
        - zsh with oh-my-zsh is used as shell.
        - `powerlevel10k` is set as the default oh-my-zsh theme.
        - `zsh-autosuggestions` plugin is installed.

    .PARAMETER Name
        The name of the distribution. If ommitted, will take WslArch by
        default.

    .PARAMETER Distribution
        The type of distribution to install. Either Arch, Alpine or Ubuntu.

    .PARAMETER RootFSURL
        URL of the root filesystem. By default, it will take the official 
        Arch Linux root filesystem.

    .PARAMETER BaseDirectory
        Base directory where to create the distribution directory. Equals to 
        $env:APPLOCALDATA (~\AppData\Local) by default.

    .PARAMETER SkipConfigure
        Skip Configuration.

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
        [ValidateSet('Arch', 'Alpine', 'Ubuntu', IgnoreCase = $true)]
        [string]$Distribution = 'Alpine',
        [string]$RootFSURL,
        [string]$BaseDirectory = $env:LOCALAPPDATA,
        [Parameter(Mandatory = $false)]
        [switch]$SkipConfigure
    )

    $properties = $distributions[$Distribution]
    Write-Host $distribution

    if ('' -eq $RootFSURL) {
        $RootFSURL = $properties['Url']
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

    $rootfs_file = "$distribution_dir\rootfs.tar.gz"

    # Donwload the root filesystem
    If (!(test-path $rootfs_file)) {
        Write-Host "####> Downloading $RootFSURL → $rootfs_file..."
        if ($PSCmdlet.ShouldProcess($rootfs_file, 'Download root fs')) {
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
        Write-Host "####> Root FS already at [$rootfs_file]."
    }

    # Retrieve the distribution if it already exists
    $current_distribution = Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name }

    If ($null -eq $current_distribution) {
        Write-Host "####> Creating distribution [$Name]..."
        if ($PSCmdlet.ShouldProcess($Name, 'Create distribution')) {
            &$wslPath --import $Name $distribution_dir $rootfs_file | Write-Verbose
        }
    }
    else {
        Write-Host "####> Distribution [$Name] already exists."
    }

    if ($false -eq $SkipConfigure) {
        $configure_script = $properties['ConfigureScript']
        Write-Host "####> Running initialization script [$configure_script] on distribution [$Name]..."
        if ($PSCmdlet.ShouldProcess($Name, 'Configure distribution')) {
            Push-Location "$module_directory"
            &$wslPath -d $Name -u root ./$configure_script 2>&1 | Write-Verbose
            Pop-Location
    
            Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name } | Set-ItemProperty -Name DefaultUid -Value 1000
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

    .PARAMETER BaseDirectory
        Base directory where to create the distribution directory. Equals to 
        $env:APPLOCALDATA (~\AppData\Local) by default.
    
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
        [string]$BaseDirectory = $env:LOCALAPPDATA,
        [Parameter(Mandatory = $false)]
        [switch]$KeepDirectory
    )

    # Retrieve the distribution if it already exists
    $current_distribution = Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name }

    # Where to install the distribution
    $distribution_dir = "$BaseDirectory\$Name"

    if ($null -eq $current_distribution) {
        Write-Error "Distribution $Name doesn't exist !" -ErrorAction Stop
    }
    else {
        if ($PSCmdlet.ShouldProcess($Name, 'Unregister distribution')) {
            Write-Verbose "Unregistering WSL distribution $Name"
            &$wslPath --unregister $Name 2>&1 | Write-Verbose 
        }
        if ($false -eq $KeepDirectory) {
            Remove-Item -Path $distribution_dir -Recurse
        }
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

    .PARAMETER BaseDirectory
        Base directory where to create the distribution directory. Equals to 
        $env:APPLOCALDATA (~\AppData\Local) by default.
    
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
        Export-Wsl toto

        Uninstall-Wsl toto -KeepDirectory
        Install-Wsl toto -SkipConfigure
    
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
        [string]$BaseDirectory = $env:LOCALAPPDATA,
        [Parameter(Mandatory = $false)]
        [string]$OutputFile
    )

    # Retrieve the distribution if it already exists
    $current_distribution = Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name }

    # Where to install the distribution
    $distribution_dir = "$BaseDirectory\$Name"

    if ($null -eq $current_distribution) {
        Write-Error "Distribution $Name doesn't exist !" -ErrorAction Stop
    }
    else {
        if ($PSCmdlet.ShouldProcess($Name, 'Export distribution')) {
            if ("" -eq $OutputFile) {
                $out_file = "$distribution_dir\rootfs.tar.gz"
            }
            else {
                $out_file = "$OutputFile"
            }
            $export_file = "$distribution_dir\export.tar"

            Write-Verbose "Exporting WSL distribution $Name to $export_file"
            &$wslPath --export $Name "$export_file" | Write-Verbose 
            $filepath = (Get-Item -Path "$export_file").Directory.FullName
            Write-Verbose "Compressing export.tar in $filepath"
            Remove-Item "$export_file.gz" -Force -ErrorAction SilentlyContinue
            &$wslPath -d $Name --cd "$filepath" gzip export.tar | Write-Verbose

            If (test-path "$out_file") {
                Remove-Item "$out_file"
            }
            Write-Verbose "Renaming $export_file.gz to $out_file"
            Move-Item -Path "$export_file.gz" "$out_file"
            Write-Host "Distribution $Name saved to $out_file"
        }
    }

}

Export-ModuleMember Install-Wsl
Export-ModuleMember Uninstall-Wsl
Export-ModuleMember Export-Wsl
