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
        The name of the distribution.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -From <String>
        The identifier of the image to create the instance from. It can be an
        already known name:
        - Arch
        - Alpine
        - Ubuntu
        - Debian

        It also can be the URL (https://...) of an existing filesystem or a
        distribution name saved through Export-WslInstance.

        It can also be a name in the form:

            incus://<os>#<release> (ex: incus://rockylinux#9)

        In this case, it will fetch the last version the specified image in
        https://images.linuxcontainers.org/images.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Image <WslImage>
        The image to use. It can be a WslImage object or a
        string that contains the path to the image.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    -BaseDirectory <String>
        Base directory where to create the distribution directory. Equals to
        $env:APPLOCALDATA\Wsl (~\AppData\Local\Wsl) by default.

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Configure [<SwitchParameter>]
        Perform Configuration. Runs the configuration script inside the newly created
        distribution to create a non root user.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Sync [<SwitchParameter>]
        Perform Synchronization. If the distribution is already installed, this will
        ensure that the image is up to date.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -WhatIf [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Confirm [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS
    None.


OUTPUTS
    None.


NOTES


        The command tries to be idempotent. It means that it will try not to
        do an operation that already has been done before.

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







RELATED LINKS
    Remove-WslInstance
    https://github.com/romkatv/powerlevel10k
    https://github.com/zsh-users/zsh-autosuggestions
    https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin



```
