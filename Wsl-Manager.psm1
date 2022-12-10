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

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', $null, Scope = 'Function', Target = "Wrap")]
Param()

class UnknownDistributionException : System.SystemException {
    UnknownDistributionException([string[]] $Name) : base("Unknown distribution(s): $($Name -join ', ')") {
    }
}

class DistributionAlreadyExistsException: System.SystemException {
    DistributionAlreadyExistsException([string] $Name) : base("Distribution $Name already exists") {
    }
}

if ($PSVersionTable.PSVersion.Major -lt 6) {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', $null, Scope = 'Function')]
    $IsWindows = $true
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


# Helper that will launch wsl.exe, correctly parsing its output encoding, and throwing an error
# if it fails.
function Wrap-Wsl {
    $hasError = $false
    try {
        $oldOutputEncoding = [System.Console]::OutputEncoding
        [System.Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        $output = &$wslPath $args
        if ($LASTEXITCODE -ne 0) {
            throw "Wsl.exe failed: $output"
            $hasError = $true
        }

    }
    finally {
        [System.Console]::OutputEncoding = $oldOutputEncoding
    }

    # $hasError is used so there's no output in case error action is silently continue.
    if (-not $hasError) {
        return $output
    }
}

enum WslDistributionState {
    Stopped
    Running
    Installing
    Uninstalling
    Converting
}

# Represents a WSL distribution.
class WslDistribution {
    WslDistribution() {
        $this | Add-Member -Name FileSystemPath -Type ScriptProperty -Value {
            return "\\wsl$\$($this.Name)"
        }

        $this | Add-Member -Name BlockFile -Type ScriptProperty -Value {
            return $this.BasePath | Get-ChildItem -Filter ext4.vhdx
        }

        $this | Add-Member -Name Size -Type ScriptProperty -Value {
            return $this.BlockFile.Length / 1MB
        }

        $defaultDisplaySet = "Name", "State", "Version", "Default"

        #Create the default property display set
        $defaultDisplayPropertySet = New-Object System.Management.Automation.PSPropertySet("DefaultDisplayPropertySet", [string[]]$defaultDisplaySet)
        $PSStandardMembers = [System.Management.Automation.PSMemberInfo[]]@($defaultDisplayPropertySet)
        $this | Add-Member MemberSet PSStandardMembers $PSStandardMembers
    }

    [string] ToString() {
        return $this.Name
    }

    [string] Unregister() {
        return Wrap-Wsl --unregister $this.Name
    }

    [string] Stop() {
        return Wrap-Wsl --terminate $this.Name
    }

    [string]$Name
    [WslDistributionState]$State
    [int]$Version
    [bool]$Default
    [Guid]$Guid
    [FileSystemInfo]$BasePath
}



# Helper to parse the output of wsl.exe --list
function Get-WslHelper() {
    Wrap-Wsl --list --verbose | Select-Object -Skip 1 | ForEach-Object { 
        $fields = $_.Split(@(" "), [System.StringSplitOptions]::RemoveEmptyEntries) 
        $defaultDistro = $false
        if ($fields.Count -eq 4) {
            $defaultDistro = $true
            $fields = $fields | Select-Object -Skip 1
        }

        [WslDistribution]@{
            "Name"    = $fields[0]
            "State"   = $fields[1]
            "Version" = [int]$fields[2]
            "Default" = $defaultDistro
        }
    }
}


# Helper to get additional distribution properties from the registry.
function Get-WslProperties([WslDistribution]$Distribution) {
    $key = Get-ChildItem "hkcu:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss" | Get-ItemProperty | Where-Object { $_.DistributionName -eq $Distribution.Name }
    if ($key) {
        $Distribution.Guid = $key.PSChildName
        $path = $key.BasePath
        if ($path.StartsWith("\\?\")) {
            $path = $path.Substring(4)
        }

        $Distribution.BasePath = Get-Item -Path $path
    }
}

function Get-Wsl {
    <#
    .SYNOPSIS
        Gets the WSL distributions installed on the computer.
    .DESCRIPTION
        The Get-Wsl cmdlet gets objects that represent the WSL distributions on the computer.
        This cmdlet wraps the functionality of "wsl.exe --list --verbose".
    .PARAMETER Name
        Specifies the distribution names of distributions to be retrieved. Wildcards are permitted. By
        default, this cmdlet gets all of the distributions on the computer.
    .PARAMETER Default
        Indicates that this cmdlet gets only the default distribution. If this is combined with other
        parameters such as Name, nothing will be returned unless the default distribution matches all the
        conditions. By default, this cmdlet gets all of the distributions on the computer.
    .PARAMETER State
        Indicates that this cmdlet gets only distributions in the specified state (e.g. Running). By
        default, this cmdlet gets all of the distributions on the computer.
    .PARAMETER Version
        Indicates that this cmdlet gets only distributions that are the specified version. By default,
        this cmdlet gets all of the distributions on the computer.
    .INPUTS
        System.String
        You can pipe a distribution name to this cmdlet.
    .OUTPUTS
        WslDistribution
        The cmdlet returns objects that represent the distributions on the computer.
    .EXAMPLE
        Get-Wsl
        Name           State Version Default
        ----           ----- ------- -------
        Ubuntu       Stopped       2    True
        Ubuntu-18.04 Running       1   False
        Alpine       Running       2   False
        Debian       Stopped       1   False
        Get all WSL distributions.
    .EXAMPLE
        Get-Wsl -Default
        Name           State Version Default
        ----           ----- ------- -------
        Ubuntu       Stopped       2    True
        Get the default distribution.
    .EXAMPLE
        Get-Wsl -Version 2 -State Running
        Name           State Version Default
        ----           ----- ------- -------
        Alpine       Running       2   False
        Get running WSL2 distributions.
    .EXAMPLE
        Get-Wsl Ubuntu* | Stop-WslDistribution
        Terminate all distributions that start with Ubuntu
    .EXAMPLE
        Get-Content distributions.txt | Get-Wsl
        Name           State Version Default
        ----           ----- ------- -------
        Ubuntu       Stopped       2    True
        Debian       Stopped       1   False
        Use the pipeline as input.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory = $false)]
        [Switch]$Default,
        [Parameter(Mandatory = $false)]
        [WslDistributionState]$State,
        [Parameter(Mandatory = $false)]
        [int]$Version
    )

    process {
        $distributions = Get-WslHelper
        if ($Default) {
            $distributions = $distributions | Where-Object {
                $_.Default
            }
        }

        if ($PSBoundParameters.ContainsKey("State")) {
            $distributions = $distributions | Where-Object {
                $_.State -eq $State
            }
        }

        if ($PSBoundParameters.ContainsKey("Version")) {
            $distributions = $distributions | Where-Object {
                $_.Version -eq $Version
            }
        }

        if ($Name.Length -gt 0) {
            $distributions = $distributions | Where-Object {
                foreach ($pattern in $Name) {
                    if ($_.Name -ilike $pattern) {
                        return $true
                    }
                }
                
                return $false
            }
            if ($null -eq $distributions) {
                throw [UnknownDistributionException] $Name
            }
        }

        # The additional registry properties aren't available if running inside WSL.
        if ($IsWindows) {
            $distributions | ForEach-Object {
                Get-WslProperties $_
            }
        }

        return $distributions
    }
}



$module_directory = ([System.IO.FileInfo]$MyInvocation.MyCommand.Path).DirectoryName
$base_wsl_directory = "$env:LOCALAPPDATA\Wsl"
$base_rootfs_directory = "$base_wsl_directory\RootFS"

$distributions = @{
    Arch   = @{
        Url             = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2022.11.01/archlinux.rootfs.tar.gz'
        ConfigureScript = 'configure_arch.sh'
        ConfiguredUrl   = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.arch.rootfs.tar.gz'
    }
    Alpine = @{
        Url             = 'https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-minirootfs-3.17.0-x86_64.tar.gz'
        ConfigureScript = 'configure_alpine.sh'
        ConfiguredUrl   = ' https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz'
    }
    Ubuntu = @{
        Url             = 'https://cloud-images.ubuntu.com/wsl/kinetic/current/ubuntu-kinetic-wsl-amd64-wsl.rootfs.tar.gz'
        ConfigureScript = 'configure_ubuntu.sh'
        ConfiguredUrl   = ' https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.arch.rootfs.tar.gz'
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

    .PARAMETER Configured
        When present, returns the rootfs already configured by its configure 
        script.

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
        [Parameter(Mandatory = $false)]
        [switch]$Configured,
        [string]$Destination = $base_rootfs_directory,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    $dist_lower = $Distribution.ToLower()
    $dist_title = (Get-Culture).TextInfo.ToTitleCase($dist_lower)
    $urlKey = 'Url'
    $rootfs_prefix = ''
    if ($true -eq $Configured) { 
        $urlKey = 'ConfiguredUrl' 
        $rootfs_prefix = 'miniwsl.'
    }
    $rootfs_file = "$Destination\$rootfs_prefix$dist_lower.rootfs.tar.gz"

    if ($distributions.ContainsKey($dist_title)) {
        $properties = $distributions[$Distribution]
        $RootFSURL = $properties[$urlKey]
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
            Write-Host "####> Downloading $RootFSURL => $rootfs_file..."
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

    .PARAMETER Configured
        If provided, install the configured version of the root filesystem.

    .PARAMETER BaseDirectory
        Base directory where to create the distribution directory. Equals to 
        $env:APPLOCALDATA\Wsl (~\AppData\Local\Wsl) by default.

    .PARAMETER DefaultUid
        Default user. 1000 by default.

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
        [Parameter(Mandatory = $false)]
        [switch]$Configured,
        [string]$BaseDirectory = $base_wsl_directory,
        [Int]$DefaultUid = 1000,
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
    $rootfs_file = Get-WslRootFS $Distribution -Configured:$Configured

    Write-Host "####> Creating distribution [$Name]..."
    if ($PSCmdlet.ShouldProcess($Name, 'Create distribution')) {
        &$wslPath --import $Name $distribution_dir $rootfs_file | Write-Verbose
    }

    if ($false -eq $SkipConfigure) {
        $configure_script = "configure_$($Distribution.ToLower()).sh"
        if ($PSCmdlet.ShouldProcess($Name, 'Configure distribution')) {
            if ((Test-Path -PathType Leaf "$module_directory\$configure_script") -And (!$Configured.IsPresent)) {
                Write-Host "####> Running initialization script [$configure_script] on distribution [$Name]..."
                Push-Location "$module_directory"
                &$wslPath -d $Name -u root ./$configure_script 2>&1 | Write-Verbose
                Pop-Location
            }
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
        The name of the distribution. Wildcards are permitted.
    
    .PARAMETER Distribution
        Specifies WslDistribution objects that represent the distributions to be removed.
    
    .PARAMETER KeepDirectory
        If specified, keep the distribution directory. This allows recreating
        the distribution from a saved root file system.

    .INPUTS
        WslDistribution, System.String
        
        You can pipe a WslDistribution object retrieved by Get-Wsl, 
        or a string that contains the distribution name to this cmdlet.

    .OUTPUTS
        None.

    .EXAMPLE
        Uninstall-Wsl toto

        Uninstall distribution named toto.
    
    .EXAMPLE
        Uninstall-Wsl test*

        Uninstall all distributions which names start by test.

    .EXAMPLE
        Get-Wsl -State Stopped | Sort-Object -Property -Size -Last 1 | Uninstall-Wsl

        Uninstall the largest non running distribution.

    .LINK
        Install-Wsl
        https://github.com/romkatv/powerlevel10k
        https://github.com/zsh-users/zsh-autosuggestions
        https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin

    .NOTES
        The command tries to be indempotent. It means that it will try not to
        do an operation that already has been done before.

    #>    
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "DistributionName", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildCards()]
        [string[]]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Distribution")]
        [WslDistribution[]]$Distribution,
        [Parameter(Mandatory = $false)]
        [switch]$KeepDirectory
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "DistributionName") {
            $Distribution = Get-Wsl $Name
        }

        if ($null -ne $Distribution) {
            $Distribution | ForEach-Object {
                if ($PSCmdlet.ShouldProcess($_.Name, "Unregister")) {
                    $_.Unregister() | Write-Verbose
                    if ($false -eq $KeepDirectory) {
                        $_.BasePath | Remove-Item -Recurse
                    }
                }
            }
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
    [WslDistribution]$Distribution = Get-Wsl $Name

    if ($null -ne $Distribution) {
        $Distribution | ForEach-Object {


            if ($OutputFile.Length -eq 0) {
                if ($OutputName.Length -eq 0) {
                    $OutputName = $Distribution.Name
                }
                $OutputFile = "$Destination\$OutputName.rootfs.tar.gz"
                If (!(test-path -PathType container $Destination)) {
                    if ($PSCmdlet.ShouldProcess($Destination, 'Create Wsl base directory')) {
                        $null = New-Item -ItemType Directory -Path $Destination
                    }
                }
            }

            if ($PSCmdlet.ShouldProcess($Distribution.Name, 'Export distribution')) {


                $export_file = $OutputFile -replace '\.gz$'

                Write-Host "####> Exporting WSL distribution $Name to $export_file..."
                Wrap-Wsl --export $Distribution.Name "$export_file" | Write-Verbose
                $file_item = Get-Item -Path "$export_file"
                $filepath = $file_item.Directory.FullName
                Write-Host "####> Compressing $export_file to $OutputFile..."
                Remove-Item "$OutputFile" -Force -ErrorAction SilentlyContinue
                Wrap-Wsl -d $Name --cd "$filepath" gzip $file_item.Name | Write-Verbose

                Write-Host "####> Distribution $Name saved to $OutputFile."
            }
        }
    }
}

function Invoke-Wsl {
    <#
    .SYNOPSIS
        Runs a command in one or more WSL distributions.
    .DESCRIPTION
        The Invoke-Wsl cmdlet executes the specified command on the specified distributions, and
        then exits.
        This cmdlet will raise an error if executing wsl.exe failed (e.g. there is no distribution with
        the specified name) or if the command itself failed.
        This cmdlet wraps the functionality of "wsl.exe <command>".
    .PARAMETER DistributionName
        Specifies the distribution names of distributions to run the command in. Wildcards are permitted.
        By default, the command is executed in the default distribution.
    .PARAMETER Distribution
        Specifies WslDistribution objects that represent the distributions to run the command in.
        By default, the command is executed in the default distribution.
    .PARAMETER User
        Specifies the name of a user in the distribution to run the command as. By default, the
        distribution's default user is used.
    .PARAMETER Arguments
        Command and arguments to pass to the 
    .INPUTS
        WslDistribution, System.String
        You can pipe a WslDistribution object retrieved by Get-WslDistribution, or a string that contains
        the distribution name to this cmdlet.
    .OUTPUTS
        System.String
        This command outputs the result of the command you executed, as text.
    .EXAMPLE
        Invoke-Wsl 'ls /etc'
        Runs a command in the default distribution.
    .EXAMPLE
        Invoke-Wsl 'whoami' -DistributionName Ubuntu* -User root
        Runs a command in all distributions whose names start with Ubuntu, as the "root" user.
    .EXAMPLE
        Get-WslDistribution -Version 2 | Invoke-Wsl 'echo $(whoami) in $WSL_DISTRO_NAME'
        Runs a command in all WSL2 distributions.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true, ParameterSetName = "DistributionName")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildCards()]
        [string[]]$DistributionName,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Distribution")]
        [WslDistribution[]]$Distribution,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$User,
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Arguments
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "DistributionName") {
            if ($DistributionName) {
                $Distribution = Get-Wsl $DistributionName
            }
            else {
                $Distribution = Get-Wsl -Default
            }
        }

        $Distribution | ForEach-Object {
            $actualArgs = @("--distribution", $_.Name)
            if ($User) {
                $actualArgs += @("--user", $User)
            }

            # Invoke /bin/bash so the whole command can be passed as a single argument.
            $actualArgs += $Arguments

            if ($PSCmdlet.ShouldProcess($_.Name, "Invoke Command")) {
                &$wslPath @actualArgs
            }
        }
    }
}

Export-ModuleMember Install-Wsl
Export-ModuleMember Uninstall-Wsl
Export-ModuleMember Export-Wsl
Export-ModuleMember Get-WslRootFS
Export-ModuleMember Get-Wsl
Export-ModuleMember Invoke-Wsl
