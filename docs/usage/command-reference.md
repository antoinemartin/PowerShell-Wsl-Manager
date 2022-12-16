---
title: Command Reference
parent: Usage
layout: default
nav_order: 3
---

<!-- markdownlint-disable MD033 -->
<details open markdown="block">
  <summary>Table of contents</summary>{: .text-delta }
- TOC
{:toc}
</details>
<!-- markdownlint-enable MD033 -->

## Install-Wsl

```text

NAME
    Install-Wsl

SYNOPSIS
    Installs and configure a minimal WSL distribution.


SYNTAX
    Install-Wsl [-Name] <String> [-Distribution <String>] [-Configured] [-BaseDirectory <String>] [-DefaultUid <Int32>] [-SkipConfigure] [-WhatIf] [-Confirm] [<CommonParameters>]


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

    -Distribution <String>
        The identifier of the distribution. It can be an already known name:
        - Arch
        - Alpine
        - Ubuntu

        It also can be an URL (https://...) or a distribution name saved through
        Export-Wsl.

    -Configured [<SwitchParameter>]
        If provided, install the configured version of the root filesystem.

    -BaseDirectory <String>
        Base directory where to create the distribution directory. Equals to
        $env:APPLOCALDATA\Wsl (~\AppData\Local\Wsl) by default.

    -DefaultUid <Int32>
        Default user. 1000 by default.

    -SkipConfigure [<SwitchParameter>]
        Skip Configuration. Only relevant for already known distributions.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Install-Wsl toto

REMARKS
    To see the examples, type: "Get-Help Install-Wsl -Examples"
    For more information, type: "Get-Help Install-Wsl -Detailed"
    For technical information, type: "Get-Help Install-Wsl -Full"
    For online help, type: "Get-Help Install-Wsl -Online"

```

## Uninstall-Wsl

```text

NAME
    Uninstall-Wsl

SYNOPSIS
    Uninstalls Arch Linux based WSL distribution.


SYNTAX
    Uninstall-Wsl [-Name] <String[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]

    Uninstall-Wsl -Distribution <WslDistribution[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command unregisters the specified distribution. It also deletes the
    distribution base root filesystem and the directory of the distribution.


PARAMETERS
    -Name <String[]>
        The name of the distribution. Wildcards are permitted.

    -Distribution <WslDistribution[]>
        Specifies WslDistribution objects that represent the distributions to be removed.

    -KeepDirectory [<SwitchParameter>]
        If specified, keep the distribution directory. This allows recreating
        the distribution from a saved root file system.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Uninstall-Wsl toto

    Uninstall distribution named toto.

    -------------------------- EXAMPLE 2 --------------------------

    PS > Uninstall-Wsl test*

    Uninstall all distributions which names start by test.

    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-Wsl -State Stopped | Sort-Object -Property -Size -Last 1 | Uninstall-Wsl

    Uninstall the largest non running distribution.

REMARKS
    To see the examples, type: "Get-Help Uninstall-Wsl -Examples"
    For more information, type: "Get-Help Uninstall-Wsl -Detailed"
    For technical information, type: "Get-Help Uninstall-Wsl -Full"
    For online help, type: "Get-Help Uninstall-Wsl -Online"

```

## Export-Wsl

```text

NAME
    Export-Wsl

SYNOPSIS
    Exports the file system of an Arch Linux WSL distrubtion.


SYNTAX
    Export-Wsl [-Name] <String> [[-OutputName] <String>] [-Destination <String>] [-OutputFile <String>] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command exports the distribution and tries to compress it with
    the `gzip` command embedded in the distribution. If no destination file
    is given, it replaces the root filesystem file in the distribution
    directory.


PARAMETERS
    -Name <String>
        The name of the distribution. If ommitted, will take WslArch by
        default.

    -OutputName <String>
        Name of the output distribution. By default, uses the name of the
        distribution.

    -Destination <String>
        Base directory where to save the root file system. Equals to
        $env:APPLOCALDAT\Wsl\RootFS (~\AppData\Local\Wsl\RootFS) by default.

    -OutputFile <String>
        The name of the output file. If it is not specified, it will overwrite
        the root file system of the distribution.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Install-Wsl toto
    wsl -d toto -u root apk add openrc docker
    Export-Wsl toto docker

    Uninstall-Wsl toto
    Install-Wsl toto -Distribution docker

REMARKS
    To see the examples, type: "Get-Help Export-Wsl -Examples"
    For more information, type: "Get-Help Export-Wsl -Detailed"
    For technical information, type: "Get-Help Export-Wsl -Full"
    For online help, type: "Get-Help Export-Wsl -Online"
```

## Get-WslRootFS

```text

NAME
    Get-WslRootFS

SYNOPSIS
    Retrieves the specified WSL distribution root filesystem.


SYNTAX
    Get-WslRootFS [-Distribution] <String> [-Configured] [-Destination <String>] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command retrieves the specified WSL distribution root file system
    if it is not already present locally. By default, the root filesystem is
    saved in $env:APPLOCALDATA\Wsl\RootFS.


PARAMETERS
    -Distribution <String>
        The distribution to get. It can be an already known name:
        - Arch
        - Alpine
        - Ubuntu

        It also can be an URL (https://...) or a distribution name saved through
        Export-Wsl.

    -Configured [<SwitchParameter>]
        When present, returns the rootfs already configured by its configure
        script.

    -Destination <String>
        Destination directory where to create the distribution directory.
        Defaults to $env:APPLOCALDATA\Wsl\RootFS (~\AppData\Local\Wsl\RootFS)
        by default.

    -Force [<SwitchParameter>]
        Force download even if the file is already there.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslRootFS Ubuntu
    Get-WslRootFS https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/alpine-minirootfs-3.17.0-x86_64.tar.gz


REMARKS
    To see the examples, type: "Get-Help Get-WslRootFS -Examples"
    For more information, type: "Get-Help Get-WslRootFS -Detailed"
    For technical information, type: "Get-Help Get-WslRootFS -Full"
    For online help, type: "Get-Help Get-WslRootFS -Online"

```

## Get-Wsl

```text

NAME
    Get-Wsl

SYNOPSIS
    Gets the WSL distributions installed on the computer.


SYNTAX
    Get-Wsl [[-Name] <String[]>] [-Default] [[-State] {Stopped | Running | Installing | Uninstalling | Converting}] [[-Version] <Int32>] [<CommonParameters>]


DESCRIPTION
    The Get-Wsl cmdlet gets objects that represent the WSL distributions on the computer.
    This cmdlet wraps the functionality of "wsl.exe --list --verbose".


PARAMETERS
    -Name <String[]>
        Specifies the distribution names of distributions to be retrieved. Wildcards are permitted. By
        default, this cmdlet gets all of the distributions on the computer.

    -Default [<SwitchParameter>]
        Indicates that this cmdlet gets only the default distribution. If this is combined with other
        parameters such as Name, nothing will be returned unless the default distribution matches all the
        conditions. By default, this cmdlet gets all of the distributions on the computer.

    -State
        Indicates that this cmdlet gets only distributions in the specified state (e.g. Running). By
        default, this cmdlet gets all of the distributions on the computer.

    -Version <Int32>
        Indicates that this cmdlet gets only distributions that are the specified version. By default,
        this cmdlet gets all of the distributions on the computer.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-Wsl
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Ubuntu-18.04 Running       1   False
    Alpine       Running       2   False
    Debian       Stopped       1   False
    Get all WSL distributions.


    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-Wsl -Default
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Get the default distribution.


    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-Wsl -Version 2 -State Running
    Name           State Version Default
    ----           ----- ------- -------
    Alpine       Running       2   False
    Get running WSL2 distributions.


    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-Wsl Ubuntu* | Stop-WslDistribution
    Terminate all distributions that start with Ubuntu


    -------------------------- EXAMPLE 5 --------------------------

    PS > Get-Content distributions.txt | Get-Wsl
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Debian       Stopped       1   False
    Use the pipeline as input.


REMARKS
    To see the examples, type: "Get-Help Get-Wsl -Examples"
    For more information, type: "Get-Help Get-Wsl -Detailed"
    For technical information, type: "Get-Help Get-Wsl -Full"

```

## Invoke-Wsl

```text

NAME
    Invoke-Wsl

SYNOPSIS
    Runs a command in one or more WSL distributions.


SYNTAX
    Invoke-Wsl [-DistributionName <String[]>] [-User <String>] [-Arguments] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]

    Invoke-Wsl -Distribution <WslDistribution[]> [-User <String>] [-Arguments] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Invoke-Wsl cmdlet executes the specified command on the specified distributions, and
    then exits.
    This cmdlet will raise an error if executing wsl.exe failed (e.g. there is no distribution with
    the specified name) or if the command itself failed.
    This cmdlet wraps the functionality of "wsl.exe <command>".


PARAMETERS
    -DistributionName <String[]>
        Specifies the distribution names of distributions to run the command in. Wildcards are permitted.
        By default, the command is executed in the default distribution.

    -Distribution <WslDistribution[]>
        Specifies WslDistribution objects that represent the distributions to run the command in.
        By default, the command is executed in the default distribution.

    -User <String>
        Specifies the name of a user in the distribution to run the command as. By default, the
        distribution's default user is used.

    -Arguments <String[]>
        Command and arguments to pass to the

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Invoke-Wsl ls /etc
    Runs a command in the default distribution.


    -------------------------- EXAMPLE 2 --------------------------

    PS > Invoke-Wsl -DistributionName Ubuntu* -User root whoami
    Runs a command in all distributions whose names start with Ubuntu, as the "root" user.


    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-Wsl -Version 2 | Invoke-Wsl sh "-c" 'echo distro=$WSL_DISTRO_NAME,defautl_user=$(whoami),flavor=$(cat /etc/os-release | grep ^PRETTY | cut -d= -f 2)'
    Runs a command in all WSL2 distributions.


REMARKS
    To see the examples, type: "Get-Help Invoke-Wsl -Examples"
    For more information, type: "Get-Help Invoke-Wsl -Detailed"
    For technical information, type: "Get-Help Invoke-Wsl -Full"

```
