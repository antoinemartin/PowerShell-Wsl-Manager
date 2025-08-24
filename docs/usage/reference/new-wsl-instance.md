# New-WslInstance

```text

NAME
    New-WslInstance

SYNOPSIS
    Creates and configures a minimal WSL instance.


SYNTAX
    New-WslInstance [-Name] <String> -From <String> [-BaseDirectory <String>] [-Configure] [-Sync] [-WhatIf] [-Confirm] [<CommonParameters>]

    New-WslInstance [-Name] <String> -Image <WslImage> [-BaseDirectory <String>] [-Configure] [-Sync] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
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


PARAMETERS
    -Name <String>
        The name of the instance.

    -From <String>
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

    -Image <WslImage>
        The image to use. It can be a WslImage object or a
        string that contains the path to the image.

    -BaseDirectory <String>
        Base directory where to create the instance directory. Equals to
        $env:APPLOCALDATA\Wsl (~\AppData\Local\Wsl) by default.

    -Configure [<SwitchParameter>]
        Perform Configuration. Runs the configuration script inside the newly created
        instance to create a non root user.

    -Sync [<SwitchParameter>]
        Perform Synchronization. If the instance is already installed, this will
        ensure that the image is up to date.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > New-WslInstance alpine -From Alpine
    Install an Alpine based WSL instance named alpine.






    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslInstance arch -From Arch
    Install an Arch based WSL instance named arch.






    -------------------------- EXAMPLE 3 --------------------------

    PS > New-WslInstance arch -From Arch -Configured
    Install an Arch based WSL instance named arch from the already configured image.






    -------------------------- EXAMPLE 4 --------------------------

    PS > New-WslInstance rocky -From incus:rocky:9
    Install a Rocky Linux based WSL instance named rocky.






    -------------------------- EXAMPLE 5 --------------------------

    PS > New-WslInstance lunar -From https://cloud-images.ubuntu.com/wsl/lunar/current/ubuntu-lunar-wsl-amd64-wsl.rootfs.tar.gz -SkipConfigure
    Install a Ubuntu 23.04 based WSL instance named lunar from the official  Canonical image and skip configuration.






    -------------------------- EXAMPLE 6 --------------------------

    PS > Get-WslImage | Where-Object { $_.Type -eq 'Local' } | New-WslInstance -Name test
    Install a WSL instance named test from the image of the first local image.






REMARKS
    To see the examples, type: "Get-Help New-WslInstance -Examples"
    For more information, type: "Get-Help New-WslInstance -Detailed"
    For technical information, type: "Get-Help New-WslInstance -Full"
    For online help, type: "Get-Help New-WslInstance -Online"


```
