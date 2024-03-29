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

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Scope = 'Function', Target = "Wrap")]
Param()

$module_directory = ([System.IO.FileInfo]$MyInvocation.MyCommand.Path).DirectoryName
$base_wsl_directory = "$env:LOCALAPPDATA\Wsl"

class UnknownDistributionException : System.SystemException {
    UnknownDistributionException([string] $Name) : base("Unknown distribution(s): $Name") {
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
            throw "wsl.exe failed: $output"
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
    }

    [string] ToString() {
        return $this.Name
    }

    [string] Unregister() {
        return Wrap-Wsl --unregister $this.Name
    }

    [void] Stop() {
        Progress "Stopping $($this.Name)..."
        $null = Wrap-Wsl --terminate $this.Name
        Success "[ok]"
    }

    [Microsoft.Win32.RegistryKey]GetRegistryKey() {
        return Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $this.Name }
    }

    [void]Rename([string]$NewName) {
        $existing = Get-Wsl $NewName -ErrorAction SilentlyContinue
        if ($null -ne $existing) {
            throw [DistributionAlreadyExistsException]$NewName
        }
        $this.GetRegistryKey() | Set-ItemProperty -Name DistributionName -Value $NewName
        $this.Name = $NewName
    }

    [ValidateNotNullOrEmpty()][string]$Name
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
                throw [UnknownDistributionException]::new($Name)
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
        - Debian

        It also can be the URL (https://...) of an existing filesystem or a 
        distribution name saved through Export-Wsl.

        It can also be a name in the form:

            lxd:<os>:<release> (ex: lxd:rockylinux:9)
        
        In this case, it will fetch the last version the specified image in
        https://uk.lxd.images.canonical.com/images. 

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
        Install-Wsl alpine
        Install an Alpine based WSL distro named alpine.
    
    .EXAMPLE
        Install-Wsl arch -Distribution Arch
        Install an Arch based WSL distro named arch.

    .EXAMPLE
        Install-Wsl arch -Distribution Arch -Configured
        Install an Arch based WSL distro named arch from the already configured image.

    .EXAMPLE
        Install-Wsl rocky -Distribution lxd:rocky:9
        Install a Rocky Linux based WSL distro named rocky.

    .EXAMPLE
        Install-Wsl lunar -Distribution https://cloud-images.ubuntu.com/wsl/lunar/current/ubuntu-lunar-wsl-amd64-wsl.rootfs.tar.gz -SkipCofniguration
        Install a Ubuntu 23.04 based WSL distro named lunar from the official  Canonical root filesystem and skip configuration.

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
    $current_distribution = Get-Wsl $Name -ErrorAction SilentlyContinue

    if ($null -ne $current_distribution) {
        throw [DistributionAlreadyExistsException] $Name
    }

    # Where to install the distribution
    $distribution_dir = "$BaseDirectory\$Name"

    # Create the directory
    If (!(test-path $distribution_dir)) {
        Progress "Creating directory [$distribution_dir]..."
        if ($PSCmdlet.ShouldProcess($distribution_dir, 'Create Distribution directory')) {
            $null = New-Item -ItemType Directory -Force -Path $distribution_dir
        }
    }
    else {
        Information "Distribution directory [$distribution_dir] already exists."
    }

    $rootfs = [WslRootFileSystem]::new($Distribution, $Configured)
    if ($PSCmdlet.ShouldProcess($rootfs.Url, 'Synchronize locally')) {
        $null = $rootfs | Sync-WslRootFileSystem
    }
    $rootfs_file = $rootfs.File.FullName

    Progress "Creating distribution [$Name] from [$rootfs_file]..."
    if ($PSCmdlet.ShouldProcess($Name, 'Create distribution')) {
        &$wslPath --import $Name $distribution_dir $rootfs_file | Write-Verbose
    }

    if ($false -eq $SkipConfigure) {
        if ($PSCmdlet.ShouldProcess($Name, 'Configure distribution')) {
            if (!$rootfs.AlreadyConfigured) {
                Progress "Running initialization script [configure.sh] on distribution [$Name]..."
                Push-Location "$module_directory"
                &$wslPath -d $Name -u root ./configure.sh 2>&1 | Write-Verbose
                Pop-Location
                if ($LASTEXITCODE -ne 0) {
                    throw "Configuration failed"
                }        
            }
            Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $Name } | Set-ItemProperty -Name DefaultUid -Value 1000
        }
    }

    Success "Done. Command to enter distribution: wsl -d $Name"
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
        [string]$Destination = [WslRootFileSystem]::BasePath.FullName,
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

                Progress "Exporting WSL distribution $Name to $export_file..."
                Wrap-Wsl --export $Distribution.Name "$export_file" | Write-Verbose
                $file_item = Get-Item -Path "$export_file"
                $filepath = $file_item.Directory.FullName
                Progress "Compressing $export_file to $OutputFile..."
                Remove-Item "$OutputFile" -Force -ErrorAction SilentlyContinue
                Wrap-Wsl -d $Name --cd "$filepath" gzip $file_item.Name | Write-Verbose

                $props =  Invoke-Wsl -DistributionName $Name cat /etc/os-release | ForEach-Object { $_ -replace '=([^"].*$)','="$1"' } | Out-String | ForEach-Object {"@{`n$_`n}"} | Invoke-Expression

                [PSCustomObject]@{
                    Os                = $OutputName
                    Release           = $props.VERSION_ID
                    Type              = [WslRootFileSystemType]::Local.ToString()
                    State             = [WslRootFileSystemState]::Synced.ToString()
                    Url               = $null
                    AlreadyConfigured = $true
                } | ConvertTo-Json | Set-Content -Path "$($OutputFile).json"
        

                Success "Distribution $Name saved to $OutputFile."
                return [WslRootFileSystem]::new([FileInfo]::new($OutputFile))
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
        Invoke-Wsl ls /etc
        Runs a command in the default distribution.
    .EXAMPLE
        Invoke-Wsl -DistributionName Ubuntu* -User root whoami
        Runs a command in all distributions whose names start with Ubuntu, as the "root" user.
    .EXAMPLE
        Get-Wsl -Version 2 | Invoke-Wsl sh "-c" 'echo distro=$WSL_DISTRO_NAME,defautl_user=$(whoami),flavor=$(cat /etc/os-release | grep ^PRETTY | cut -d= -f 2)'
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

$tabCompletionScript = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    (Get-WslHelper).Name | Where-Object { $_ -ilike "$wordToComplete*" } | Sort-Object
}

Register-ArgumentCompleter -CommandName Get-Wsl,Uninstall-Wsl,Export-Wsl -ParameterName Name -ScriptBlock $tabCompletionScript
Register-ArgumentCompleter -CommandName Invoke-Wsl -ParameterName DistributionName -ScriptBlock $tabCompletionScript
Register-ArgumentCompleter -CommandName Install-Wsl -ParameterName Distribution -ScriptBlock { [WslRootFileSystem]::Distributions.keys }

Export-ModuleMember Install-Wsl
Export-ModuleMember Uninstall-Wsl
Export-ModuleMember Export-Wsl
Export-ModuleMember Get-Wsl
Export-ModuleMember Invoke-Wsl
Export-ModuleMember New-WslRootFileSystem
Export-ModuleMember Sync-WslRootFileSystem
Export-ModuleMember Get-WslRootFileSystem
Export-ModuleMember Remove-WslRootFileSystem
Export-ModuleMember Get-LXDRootFileSystem
Export-ModuleMember New-WslRootFileSystemHash
