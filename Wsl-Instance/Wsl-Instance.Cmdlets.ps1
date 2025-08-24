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

function Set-WslDefaultInstance {
    <#
    .SYNOPSIS
    Sets the default WSL instance.

    .PARAMETER Name
    The name of the WSL instance to set as default.

    .PARAMETER Instance
    The WSL instance object to set as default.

    .EXAMPLE
    Set-WslDefaultInstance -Name "alpine"
    Sets the default WSL instance to "alpine".

    .EXAMPLE
    Set-WslDefaultInstance -Instance $myInstance
    Sets the default WSL instance to the specified instance object.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = 'InstanceName', Position=0)]
        [string]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $false, ParameterSetName = 'InstanceObject')]
        [WslInstance]$Instance
    )

    if ($PSCmdlet.ParameterSetName -eq 'InstanceName') {
        $Instance = Get-WslInstance -Name $Name
    }

    if ($PSCmdlet.ShouldProcess($Name, "Set default WSL instance")) {
        $baseKey = $null
        try {
            $baseKey = Get-WslRegistryBaseKey
            $key = $baseKey.GetSubKeyNames() |
                Where-Object {
                    $subKey = $baseKey.OpenSubKey($_, $false)
                    try {
                        $subKey.GetValue('DistributionName') -eq $Instance.Name
                    } finally {
                        if ($null -ne $subKey) {
                            $subKey.Close()
                        }
                    }
                } | Select-Object -First 1
            $baseKey.SetValue('DefaultDistribution', $key)
            Success "Default instance set to $($Instance.Name)"
        } finally {
            if ($null -ne $baseKey) {
                $baseKey.Close()
            }
        }
    }
    return $Instance
}


function Get-WslInstance {
    <#
    .SYNOPSIS
        Gets the WSL instances installed on the computer.
    .DESCRIPTION
        The Get-WslInstance cmdlet gets objects that represent the WSL instances on the computer.
        This cmdlet wraps the functionality of "wsl.exe --list --verbose".
    .PARAMETER Name
        Specifies the instance names of instances to be retrieved. Wildcards are permitted. By
        default, this cmdlet gets all of the instances on the computer.
    .PARAMETER Default
        Indicates that this cmdlet gets only the default instance. If this is combined with other
        parameters such as Name, nothing will be returned unless the default instance matches all the
        conditions. By default, this cmdlet gets all of the instances on the computer.
    .PARAMETER State
        Indicates that this cmdlet gets only instances in the specified state (e.g. Running). By
        default, this cmdlet gets all of the instances on the computer.
    .PARAMETER Version
        Indicates that this cmdlet gets only instances that are the specified version. By default,
        this cmdlet gets all of the instances on the computer.
    .INPUTS
        System.String
        You can pipe a instance name to this cmdlet.
    .OUTPUTS
        WslInstance
        The cmdlet returns objects that represent the instances  on the computer.
    .EXAMPLE
        Get-Wsl
        Name           State Version Default
        ----           ----- ------- -------
        Ubuntu       Stopped       2    True
        Ubuntu-18.04 Running       1   False
        Alpine       Running       2   False
        Debian       Stopped       1   False
        Get all WSL instances.
    .EXAMPLE
        Get-WslInstance -Default
        Name           State Version Default
        ----           ----- ------- -------
        Ubuntu       Stopped       2    True
        Get the default instance.
    .EXAMPLE
        Get-WslInstance -Version 2 -State Running
        Name           State Version Default
        ----           ----- ------- -------
        Alpine       Running       2   False
        Get running WSL2 instances.
    .EXAMPLE
        Get-WslInstance Ubuntu* | Stop-WslInstance
        Terminate all instances that start with Ubuntu
    .EXAMPLE
        Get-Content instances.txt | Get-WslInstance
        Name           State Version Default
        ----           ----- ------- -------
        Ubuntu       Stopped       2    True
        Debian       Stopped       1   False
        Use the pipeline as input.
    #>
    [CmdletBinding()]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory = $false)]
        [Switch]$Default,
        [Parameter(Mandatory = $false)]
        [WslInstanceState]$State,
        [Parameter(Mandatory = $false)]
        [int]$Version
    )

    process {
        $instances = Get-WslHelper
        if ($Default) {
            $instances = $instances | Where-Object {
                $_.Default
            }
        }

        if ($PSBoundParameters.ContainsKey("State")) {
            $instances = $instances | Where-Object {
                $_.State -eq $State
            }
        }

        if ($PSBoundParameters.ContainsKey("Version")) {
            $instances = $instances | Where-Object {
                $_.Version -eq $Version
            }
        }

        if ($Name.Length -gt 0) {
            $instances = $instances | Where-Object {
                foreach ($pattern in $Name) {
                    if ($_.Name -ilike $pattern) {
                        return $true
                    }
                }

                return $false
            }
            if ($null -eq $instances) {
                throw [UnknownWslInstanceException]::new($Name)
            }
        }

        # The additional registry properties aren't available if running inside WSL.
        $instances | ForEach-Object {
            $_.RetrieveProperties()
        }

        return $instances
    }
}

function Invoke-WslConfigure {
    <#
    .SYNOPSIS
        Configures a WSL instance.

    .DESCRIPTION
        This function runs the configuration script inside the specified WSL instance
        to create a non-root user.

    .PARAMETER Name
        The name of the WSL instance to configure.

    .PARAMETER Uid
        The user ID to set as the default for the instance.
    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([WslInstance])]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name,
        [Parameter(Position = 1, Mandatory = $false)]
        [int]$Uid = 1000
    )

    $existing = try { Get-WslInstance $Name -ErrorAction SilentlyContinue } catch { $null }

    if ($null -eq $existing) {
        throw [UnknownWslInstanceException]::new($NewName)
    }

    if ($PSCmdlet.ShouldProcess($Name, 'Configure instance')) {
        $existing.Configure($true, $Uid)
    }
    return $existing
}

function New-WslInstance {
    <#
    .SYNOPSIS
        Creates and configures a minimal WSL instance.

    .DESCRIPTION
        This command performs the following operations:
        - Create an Instance directory
        - Download the Image if needed.
        - Create the WSL instance.
        - Configure the WSL instance if needed.

        The instance is configured as follow:
        - A user named after the name of the instance (arch, alpine or
        ubuntu) is set as the default user.
        - zsh with oh-my-zsh is used as shell.
        - `powerlevel10k` is set as the default oh-my-zsh theme.
        - `zsh-autosuggestions` plugin is installed.

    .PARAMETER Name
        The name of the instance.

    .PARAMETER From
        The identifier of the image to create the instance from. It can be an
        already known name:
        - Arch
        - Alpine
        - Ubuntu
        - Debian

        It also can be the URL (https://...) of an existing filesystem or a
        image name saved through Export-WslInstance.

        It can also be a name in the form:

            incus://<os>#<release> (ex: incus://rockylinux#9)

        In this case, it will fetch the last version the specified image in
        https://images.linuxcontainers.org/images.

    .PARAMETER Image
        The image to use. It can be a WslImage object or a
        string that contains the path to the image.

    .PARAMETER BaseDirectory
        Base directory where to create the instance directory. Equals to
        $env:APPLOCALDATA\Wsl (~\AppData\Local\Wsl) by default.

    .PARAMETER Configure
        Perform Configuration. Runs the configuration script inside the newly created
        instance to create a non root user.

    .PARAMETER Sync
        Perform Synchronization. If the instance is already installed, this will
        ensure that the image is up to date.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-WslInstance alpine -From Alpine
        Install an Alpine based WSL instance named alpine.

    .EXAMPLE
        New-WslInstance arch -From Arch
        Install an Arch based WSL instance named arch.

    .EXAMPLE
        New-WslInstance arch -From Arch -Configured
        Install an Arch based WSL instance named arch from the already configured image.

    .EXAMPLE
        New-WslInstance rocky -From incus:rocky:9
        Install a Rocky Linux based WSL instance named rocky.

    .EXAMPLE
        New-WslInstance lunar -From https://cloud-images.ubuntu.com/wsl/lunar/current/ubuntu-lunar-wsl-amd64-wsl.rootfs.tar.gz -SkipConfigure
        Install a Ubuntu 23.04 based WSL instance named lunar from the official  Canonical image and skip configuration.

    .EXAMPLE
         Get-WslImage | Where-Object { $_.Type -eq 'Local' } | New-WslInstance -Name test
        Install a WSL instance named test from the image of the first local image.
    .LINK
        Remove-WslInstance
        https://github.com/romkatv/powerlevel10k
        https://github.com/zsh-users/zsh-autosuggestions
        https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin

    .NOTES
        The command tries to be idempotent. It means that it will try not to
        do an operation that already has been done before.

    #>
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([WslInstance])]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [string]$From,
        [Parameter(ValueFromPipeline = $true, Mandatory = $true, ParameterSetName = 'Image')]
        [WslImage]$Image,
        [string]$BaseDirectory = $null,
        [Parameter(Mandatory = $false)]
        [switch]$Configure,
        [Parameter(Mandatory = $false)]
        [switch]$Sync
    )

    # Retrieve the instance if it already exists
    $current_distribution = try {
        Get-WslInstance $Name
    } catch {
        # Ignore not found errors
        $null
    }

    if ($null -ne $current_distribution) {
        throw [WslInstanceAlreadyExistsException]::new($Name)
    }

    if (-not $BaseDirectory) {
        $BaseDirectory = [WslInstance]::DistrosRoot.FullName
    }
    # Where to install the instance
    $distribution_dir = Join-Path -Path $BaseDirectory -ChildPath $Name

    # Create the directory
    If (!(test-path $distribution_dir)) {
        Progress "Creating directory [$distribution_dir]..."
        if ($PSCmdlet.ShouldProcess($distribution_dir, 'Create Instance directory')) {
            $null = New-Item -ItemType Directory -Force -Path $distribution_dir
        }
    }
    else {
        Information "Instance directory [$distribution_dir] already exists."
    }

    if ($PSCmdlet.ParameterSetName -eq "Name") {
        $Image = [WslImage]::new($From)
        if (($Sync -eq $true -or -not $Image.IsAvailableLocally) -and $PSCmdlet.ShouldProcess($Image.Url, 'Synchronize locally')) {
            $null = $Image | Sync-WslImage
        }
    } elseif ($PSCmdlet.ParameterSetName -eq "Image") {
        $Image = $Image
    }

    $Image_file = $Image.File.FullName

    Progress "Creating instance [$Name] from [$Image_file]..."
    if ($PSCmdlet.ShouldProcess($Name, 'Create instance')) {
        Wrap-Wsl-Raw -Arguments '--import',$Name,$distribution_dir,$Image_file | Write-Verbose
    }

    $Uid = $Image.Uid
    $wsl = [WslInstance]::new($Name)

    if ($true -eq $Configure) {
        if ($PSCmdlet.ShouldProcess($Name, 'Configure instance')) {
            if (!$Image.Configured) {
                $wsl.Configure($true, $Uid)
            } else {
                Information "Instance [$Name] is already configured, skipping configuration."
            }
        }
    } else {
        if ($Uid -ne 0 -and $PSCmdlet.ShouldProcess($Name, 'Set default UID')) {
            $wsl.SetDefaultUid($Uid)
        }
    }

    Success "Done. Command to enter instance: Invoke-WslInstance -In $Name or wsl -d $Name"
    return $wsl
}

function Remove-WslInstance {
    <#
    .SYNOPSIS
        Removes WSL instance.

    .DESCRIPTION
        This command remove the specified instance. It also deletes the
        instance vhdx file and the directory of the instance. It's the
        equivalent of `wsl --unregister`.

    .PARAMETER Name
        The name of the instance. Wildcards are permitted.

    .PARAMETER Instance
        Specifies WslInstance objects that represent the instances to be removed.

    .PARAMETER KeepDirectory
        If specified, keep the instance directory. This allows recreating
        the instance from a saved image.

    .INPUTS
        WslInstance, System.String

        You can pipe a WslInstance object retrieved by Get-WslInstance,
        or a string that contains the instance name to this cmdlet.

    .OUTPUTS
        None.

    .EXAMPLE
        Remove-WslInstance toto

        Uninstall instance named toto.

    .EXAMPLE
        Remove-WslInstance test*

        Uninstall all instances which names start by test.

    .EXAMPLE
        Get-WslInstance -State Stopped | Sort-Object -Property -Size -Last 1 | Remove-WslInstance

        Uninstall the largest non running instance.

    .LINK
        New-WslInstance
        https://github.com/romkatv/powerlevel10k
        https://github.com/zsh-users/zsh-autosuggestions
        https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin

    .NOTES
        The command tries to be idempotent. It means that it will try not to
        do an operation that already has been done before.

    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "InstanceName", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildCards()]
        [string[]]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Instance")]
        [WslInstance[]]$Instance,
        [Parameter(Mandatory = $false)]
        [switch]$KeepDirectory
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "InstanceName") {
            $Instance = Get-WslInstance $Name
        }

        if ($null -ne $Instance) {
            $Instance | ForEach-Object {
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


function Export-WslInstance {
    <#
    .SYNOPSIS
        Exports the file system of a WSL instance.

    .DESCRIPTION
        This command exports the instance and tries to compress it with
        the `gzip` command embedded in the instance. If no destination file
        is given, it creates or replaces an image file named after the instance
        in the images directory ($env:APPLOCALDATA\Wsl\RootFS).

    .PARAMETER Name
        The name of the instance.

    .PARAMETER OutputName
        Name of the output image. By default, uses the name of the
        instance.

    .PARAMETER Destination
        Base directory where to save the root file system. Equals to
        $env:APPLOCALDATA\Wsl\RootFS (~\AppData\Local\Wsl\RootFS) by default.

    .PARAMETER OutputFile
        The name of the output file. If it is not specified, it will overwrite
        the root file system of the instance.

    .INPUTS
        None.

    .OUTPUTS
        None.

    .EXAMPLE
        New-WslInstance toto
        wsl -d toto -u root apk add openrc docker
        Export-WslInstance toto docker

        Remove-WslInstance toto
        New-WslInstance toto -From docker

    .LINK
        New-WslInstance
        https://github.com/romkatv/powerlevel10k
        https://github.com/zsh-users/zsh-autosuggestions
        https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin

    .NOTES
        The command tries to be idempotent. It means that it will try not to
        do an operation that already has been done before.

    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingInvokeExpression', '',
        Justification='Ingesting /etc/os-release properties into a hashtable')]
    [CmdletBinding(SupportsShouldProcess)]
    [OutputType([WslImage])]
    param(
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Name,
        [Parameter(Position = 1, Mandatory = $false)]
        [string]$OutputName,
        [string]$Destination = $null,
        [Parameter(Mandatory = $false)]
        [string]$OutputFile
    )

    # Retrieve the instance if it already exists
    [WslInstance]$Instance = Get-WslInstance $Name

    if ($null -ne $Instance) {
        if (-not $Destination) {
            $Destination = [WslImage]::BasePath.FullName
        }
        $Instance | ForEach-Object {


            if ($OutputFile.Length -eq 0) {
                if ($OutputName.Length -eq 0) {
                    $OutputName = $Instance.Name
                }
                $OutputFile =  Join-Path -Path $Destination -ChildPath "$OutputName.rootfs.tar.gz"
                If (!(test-path -PathType container $Destination)) {
                    if ($PSCmdlet.ShouldProcess($Destination, 'Create Wsl base directory')) {
                        $null = New-Item -ItemType Directory -Path $Destination
                    }
                }
            }

            if ($PSCmdlet.ShouldProcess($Instance.Name, 'Export instance')) {

                $export_file = $OutputFile -replace '\.gz$'

                Progress "Exporting WSL instance $Name to $export_file..."
                Wrap-Wsl -Arguments --export,$Instance.Name,"$export_file" | Write-Verbose
                $file_item = Get-Item -Path "$export_file"
                $filepath = $file_item.Directory.FullName
                Progress "Compressing $export_file to $OutputFile..."
                Remove-Item "$OutputFile" -Force -ErrorAction SilentlyContinue
                Wrap-Wsl -Arguments --distribution,$Name,"--cd","$filepath","gzip",$file_item.Name | Write-Verbose

                $props =  Invoke-WslInstance -In $Name cat /etc/os-release | ForEach-Object { $_ -replace '=([^"].*$)','="$1"' } | Out-String | ForEach-Object {"@{`n$_`n}"} | Invoke-Expression

                [PSCustomObject]@{
                    Name              = $OutputName
                    Os                = $props.ID
                    Release           = $props.VERSION_ID
                    Type              = [WslImageType]::Local.ToString()
                    State             = [WslImageState]::Synced.ToString()
                    Url               = $null
                    Configured        = $true
                } | ConvertTo-Json | Set-Content -Path "$($OutputFile).json"


                Success "Instance $Name saved to $OutputFile."
                return [WslImage]::new([FileInfo]::new($OutputFile))
            }
        }
    }
}

function Invoke-WslInstance {
    <#
    .SYNOPSIS
        Runs a command in one or more WSL instances.
    .DESCRIPTION
        The Invoke-WslInstance cmdlet executes the specified command on the specified instances, and
        then exits.
        This cmdlet will raise an error if executing wsl.exe failed (e.g. there is no instance with
        the specified name) or if the command itself failed.
        This cmdlet wraps the functionality of "wsl.exe <command>".
    .PARAMETER In
        Specifies the instance names of instances to run the command in. Wildcards are permitted.
        By default, the command is executed in the default instance.
    .PARAMETER Instance
        Specifies WslInstance objects that represent the instances to run the command in.
        By default, the command is executed in the default instance.
    .PARAMETER User
        Specifies the name of a user in the instance to run the command as. By default, the
        instance's default user is used.
    .PARAMETER Arguments
        Command and arguments to pass to the
    .INPUTS
        WslInstance, System.String
        You can pipe a WslInstance object retrieved by Get-WslInstance, or a string that contains
        the instance name to this cmdlet.
    .OUTPUTS
        System.String
        This command outputs the result of the command you executed, as text.
    .EXAMPLE
        Invoke-WslInstance ls /etc
        Runs a command in the default instance.
    .EXAMPLE
        Invoke-WslInstance -In Ubuntu* -User root whoami
        Runs a command in all instances whose names start with Ubuntu, as the "root" user.
    .EXAMPLE
        Get-WslInstance -Version 2 | Invoke-WslInstance sh "-c" 'echo distro=$WSL_DISTRO_NAME,default_user=$(whoami),flavor=$(cat /etc/os-release | grep ^PRETTY | cut -d= -f 2)'
        Runs a command in all WSL2 instances.
    #>

    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $false, ParameterSetName = "InstanceName")]
        [ValidateNotNullOrEmpty()]
        [SupportsWildCards()]
        [string[]]$In,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Instance")]
        [WslInstance[]]$Instance,
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [string]$User,
        [Parameter(Mandatory = $false, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "InstanceName") {
            if ($In) {
                $Instance = Get-WslInstance $In
            }
            else {
                $Instance = Get-WslInstance -Default
            }
        }

        $Instance | ForEach-Object {
            $actualArgs = @("--distribution", $_.Name)
            if ($User) {
                $actualArgs += @("--user", $User)
            }

            # Invoke /bin/bash so the whole command can be passed as a single argument.
            if ($Arguments.Count -ne 0) {
                $actualArgs += $Arguments
            }

            if ($PSCmdlet.ShouldProcess($_.Name, $Arguments -join " ")) {
                Wrap-Wsl-Raw @actualArgs
            }
        }
    }
}


function Rename-WslInstance {
    <#
    .SYNOPSIS
        Renames a WSL instance.
    .DESCRIPTION
        The Rename-WslInstance cmdlet renames a WSL instance to a new name.
    .PARAMETER Name
        Specifies the name of the instance to rename.
    .PARAMETER Instance
        Specifies the WslInstance object representing the instance to rename.
    .PARAMETER NewName
        Specifies the new name for the instance.
    .INPUTS
        WslInstance
        You can pipe a WslInstance object retrieved by Get-WslInstance
    .OUTPUTS
        WslInstance
        This command outputs the renamed WSL instance.
    .EXAMPLE
        Rename-WslInstance alpine alpine321
        Renames the instance named "alpine" to "alpine321".
    .EXAMPLE
        Get-WslInstance -Name alpine | Rename-WslInstance -NewName alpine321
        Renames the instance named "alpine" to "alpine321".
    .LINK
        New-WslInstance
    #>
    [CmdletBinding()]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $true, ParameterSetName = 'Name', Position = 0)]
        [string]$Name,

        [Parameter(Mandatory = $true, ParameterSetName = 'Instance', ValueFromPipeline = $true)]
        [WslInstance]$Instance,

        [Parameter(Mandatory = $true, Position = 1)]
        [ValidateNotNullOrEmpty()]
        [string]$NewName
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Instance = Get-WslInstance $Name
        }
        $Instance.Rename($NewName)
        return $Instance
    }
}


function Stop-WslInstance {
    <#
    .SYNOPSIS
        Stops one or more WSL instances.
    .DESCRIPTION
        The Stop-WslInstance cmdlet terminates the specified WSL instances. This cmdlet wraps
        the functionality of "wsl.exe --terminate".
    .PARAMETER Name
        Specifies the instance names of instances to be stopped. Wildcards are permitted.
    .PARAMETER Instance
        Specifies WslInstance objects that represent the instances to be stopped.
    .INPUTS
        WslInstance, System.String
        You can pipe a WslInstance object retrieved by Get-WslInstance, or a string that contains
        the instance name to this cmdlet.
    .OUTPUTS
        None.
    .EXAMPLE
        Stop-WslInstance Ubuntu
        Stops the Ubuntu instance.
    .EXAMPLE
        Stop-WslInstance -Name test*
        Stops all instances whose names start with "test".
    .EXAMPLE
        Get-WslInstance -State Running | Stop-WslInstance
        Stops all running instances.
    .EXAMPLE
        Get-WslInstance Ubuntu,Debian | Stop-WslInstance
        Stops the Ubuntu and Debian instances.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "InstanceName", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildCards()]
        [string[]]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Instance")]
        [WslInstance[]]$Instance
    )

    process {
        $instances = if ($PSCmdlet.ParameterSetName -eq "InstanceName") {
            Get-WslInstance -Name $Name
        } else {
            $Instance
        }

        foreach ($distro in $instances) {
            if ($PSCmdlet.ShouldProcess($distro.Name, "Stop")) {
                $distro.Stop()
            }
            $distro
        }
    }
}


function Set-WslDefaultUid {
    <#
    .SYNOPSIS
        Sets the default UID for one or more WSL instances.
    .DESCRIPTION
        The Set-WslDefaultUid cmdlet sets the default user ID (UID) for the specified WSL instances.
        This determines which user account is used when launching the instance without specifying a user.
    .PARAMETER Name
        Specifies the instance names of instances to set the default UID for. Wildcards are permitted.
    .PARAMETER Instance
        Specifies WslInstance objects that represent the instances to set the default UID for.
    .PARAMETER Uid
        Specifies the user ID to set as default. Common values are 0 (root) or 1000 (first regular user).
    .INPUTS
        WslInstance, System.String
        You can pipe a WslInstance object retrieved by Get-WslInstance, or a string that contains
        the instance name to this cmdlet.
    .OUTPUTS
        None.
    .EXAMPLE
        Set-WslDefaultUid -Name Ubuntu -Uid 1000
        Sets the default UID to 1000 for the Ubuntu instance.
    .EXAMPLE
        Set-WslDefaultUid -Name test* -Uid 0
        Sets the default UID to 0 (root) for all instances whose names start with "test".
    .EXAMPLE
        Get-WslInstance -Version 2 | Set-WslDefaultUid -Uid 1000
        Sets the default UID to 1000 for all WSL2 instances.
    .EXAMPLE
        Get-WslInstance Ubuntu,Debian | Set-WslDefaultUid -Uid 1000
        Sets the default UID to 1000 for the Ubuntu and Debian instances.
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([WslInstance])]
    param(
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "InstanceName", Position = 0)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildCards()]
        [string[]]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Instance", Position = 0)]
        [WslInstance[]]$Instance,
        [Parameter(Mandatory = $true, Position = 1)]
        [int]$Uid
    )

    process {
        $instances = if ($PSCmdlet.ParameterSetName -eq "InstanceName") {
            Get-WslInstance -Name $Name
        } else {
            $Instance
        }

        foreach ($distro in $instances) {
            if ($PSCmdlet.ShouldProcess($distro.Name, "Set default UID to $Uid")) {
                $distro.SetDefaultUid($Uid)
            }
            $distro
        }
    }
}
