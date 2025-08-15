# Install-Wsl

```text

NAME
    Install-Wsl

SYNOPSIS
    Installs and configure a minimal WSL distribution.


SYNTAX
    Install-Wsl [-Name] <String> -Distribution <String> [-BaseDirectory <String>] [-Configure] [-Sync] [-WhatIf] [-Confirm] [<CommonParameters>]

    Install-Wsl [-Name] <String> -RootFileSystem <WslRootFileSystem> [-BaseDirectory <String>] [-Configure] [-Sync] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
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


PARAMETERS
    -Name <String>
        The name of the distribution.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Distribution <String>
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

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -RootFileSystem <WslRootFileSystem>
        The root filesystem to use. It can be a WslRootFileSystem object or a
        string that contains the path to the root filesystem.

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
        ensure that the root filesystem is up to date.

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

    PS > Install-Wsl alpine -Distribution Alpine
    Install an Alpine based WSL distro named alpine.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Install-Wsl arch -Distribution Arch
    Install an Arch based WSL distro named arch.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Install-Wsl arch -Distribution Arch -Configured
    Install an Arch based WSL distro named arch from the already configured image.






    -------------------------- EXAMPLE 4 --------------------------

    PS > Install-Wsl rocky -Distribution incus:rocky:9
    Install a Rocky Linux based WSL distro named rocky.






    -------------------------- EXAMPLE 5 --------------------------

    PS > Install-Wsl lunar -Distribution https://cloud-images.ubuntu.com/wsl/lunar/current/ubuntu-lunar-wsl-amd64-wsl.rootfs.tar.gz -SkipConfigure
    Install a Ubuntu 23.04 based WSL distro named lunar from the official  Canonical root filesystem and skip configuration.






    -------------------------- EXAMPLE 6 --------------------------

    PS > Get-WslRootFileSystem | Where-Object { $_.Type -eq 'Local' } | Install-Wsl -Name test
    Install a WSL distribution named test from the root filesystem of the first local root filesystem.







RELATED LINKS
    Uninstall-Wsl
    https://github.com/romkatv/powerlevel10k
    https://github.com/zsh-users/zsh-autosuggestions
    https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin



```
