---
title: Command Reference
parent: Usage
layout: default
nav_order: 4
---

<!-- markdownlint-disable MD033 -->
<details open markdown="block">
  <summary>Table of contents</summary>{: .text-delta }
- TOC
{:toc}
</details>
<!-- markdownlint-enable MD033 -->

{: .note }

> The content below is generated with the following command:
>
> ````````bash
> PS> Import-PowerShellDataFile ./Wsl-Manager.psd1 | Select-Object -ExpandProperty FunctionsToExport | % { write-output "`n## $_`n`n``````text"; get-help -Detailed $_; write-output "```````n" } | out-string | set-content test.md
>
> ````````

## Install-Wsl

```text

NAME
    Install-Wsl

SYNOPSIS
    Installs and configure a minimal WSL distribution.


SYNTAX
    Install-Wsl [-Name] <String> -Distribution <String> [-Configured] [-BaseDirectory <String>] [-Configure] [-Sync] [-WhatIf] [-Confirm] [<CommonParameters>]

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

    -Distribution <String>
        The identifier of the distribution. It can be an already known name:
        - Arch
        - Alpine
        - Ubuntu
        - Debian
        - OpenSuse

        It also can be the URL (https://...) of an existing filesystem or a
        distribution name saved through Export-Wsl.

        It can also be a name in the form:

            incus:<os>:<release> (ex: incus:rockylinux:9)

        In this case, it will fetch the last version the specified image in
        https://images.linuxcontainers.org/images.

    -Configured [<SwitchParameter>]
        If provided, install the configured version of the root filesystem.

    -RootFileSystem <WslRootFileSystem>
        The root filesystem to use. It can be a WslRootFileSystem object or a
        string that contains the path to the root filesystem.

    -BaseDirectory <String>
        Base directory where to create the distribution directory. Equals to
        $env:APPLOCALDATA\Wsl (~\AppData\Local\Wsl) by default.

    -Configure [<SwitchParameter>]
        Perform Configuration. Runs the configuration script inside the newly created
        distribution to create a non root user.

    -Sync [<SwitchParameter>]
        Perform Synchronization. If the distribution is already installed, this will
        ensure that the root filesystem is up to date.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

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

    PS > Install-Wsl lunar -Distribution https://cloud-images.ubuntu.com/wsl/lunar/current/ubuntu-lunar-wsl-amd64-wsl.rootfs.tar.gz
    Install a Ubuntu 23.04 based WSL distro named lunar from the official  Canonical root filesystem.


    -------------------------- EXAMPLE 6 --------------------------

    PS > Get-WslRootFileSystem | Where-Object { $_.Type -eq 'Local' } | Install-Wsl -Name test
    Install a WSL distribution named test from the root filesystem of the first local root filesystem.


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
    Uninstalls WSL distribution.


SYNTAX
    Uninstall-Wsl [-Name] <String[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]

    Uninstall-Wsl -Distribution <WslDistribution[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command unregister the specified distribution. It also deletes the
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
    Exports the file system of a WSL distribution.


SYNTAX
    Export-Wsl [-Name] <String> [[-OutputName] <String>] [-Destination <String>] [-OutputFile <String>] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command exports the distribution and tries to compress it with
    the `gzip` command embedded in the distribution. If no destination file
    is given, it replaces the root filesystem file in the distribution
    directory.


PARAMETERS
    -Name <String>
        The name of the distribution.

    -OutputName <String>
        Name of the output distribution. By default, uses the name of the
        distribution.

    -Destination <String>
        Base directory where to save the root file system. Equals to
        $env:APPLOCALDATA\Wsl\RootFS (~\AppData\Local\Wsl\RootFS) by default.

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

    PS > Get-Wsl -Version 2 | Invoke-Wsl sh "-c" 'echo distro=$WSL_DISTRO_NAME,default_user=$(whoami),flavor=$(cat /etc/os-release | grep ^PRETTY | cut -d= -f 2)'
    Runs a command in all WSL2 distributions.


REMARKS
    To see the examples, type: "Get-Help Invoke-Wsl -Examples"
    For more information, type: "Get-Help Invoke-Wsl -Detailed"
    For technical information, type: "Get-Help Invoke-Wsl -Full"

```

## Invoke-WslConfigure

```text
NAME
    Invoke-WslConfigure

SYNOPSIS
    Configures a WSL distribution.


SYNTAX
    Invoke-WslConfigure [-Name] <String> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This function runs the configuration script inside the specified WSL distribution
    to create a non-root user.


RELATED LINKS

REMARKS
    To see the examples, type: "Get-Help Invoke-WslConfigure -Examples"
    For more information, type: "Get-Help Invoke-WslConfigure -Detailed"
    For technical information, type: "Get-Help Invoke-WslConfigure -Full"

```

## Rename-Wsl

```test
NAME
    Rename-Wsl

SYNOPSIS
    Renames a WSL distribution.


SYNTAX
    Rename-Wsl [-Name] <String> [-NewName] <String> [<CommonParameters>]

    Rename-Wsl -Distribution <WslDistribution> [-NewName] <String> [<CommonParameters>]


DESCRIPTION
    The Rename-Wsl cmdlet renames a WSL distribution to a new name.


RELATED LINKS
    Install-Wsl

REMARKS
    To see the examples, type: "Get-Help Rename-Wsl -Examples"
    For more information, type: "Get-Help Rename-Wsl -Detailed"
    For technical information, type: "Get-Help Rename-Wsl -Full"
    For online help, type: "Get-Help Rename-Wsl -Online"
```

## Stop-Wsl

```test
NAME
    Stop-Wsl

SYNOPSIS
    Stops one or more WSL distributions.


SYNTAX
    Stop-Wsl [-Name] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]

    Stop-Wsl -Distribution <WslDistribution[]> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Stop-Wsl cmdlet terminates the specified WSL distributions. This cmdlet wraps
    the functionality of "wsl.exe --terminate".


RELATED LINKS

REMARKS
    To see the examples, type: "Get-Help Stop-Wsl -Examples"
    For more information, type: "Get-Help Stop-Wsl -Detailed"
    For technical information, type: "Get-Help Stop-Wsl -Full"
```

## New-WslRootFileSystem

```text
NAME
    New-WslRootFileSystem

SYNOPSIS
    Creates a WslRootFileSystem object.


SYNTAX
    New-WslRootFileSystem [-Distribution] <String> [[-Configured]] [<CommonParameters>]

    New-WslRootFileSystem -Path <String> [<CommonParameters>]

    New-WslRootFileSystem -File <FileInfo> [<CommonParameters>]


DESCRIPTION
    WslRootFileSystem object retrieve and provide information about available root
    filesystems.


PARAMETERS
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

    -Configured [<SwitchParameter>]
        Whether the distribution is configured. This parameter is relevant for Builtin
        distributions.

    -Path <String>
        The path of the root filesystem. Should be a file ending with `rootfs.tar.gz`.
        It will try to extract the OS and Release from the filename (in /etc/os-release).

    -File <FileInfo>
        A FileInfo object of the compressed root filesystem.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > New-WslRootFileSystem incus:alpine:3.19
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    The WSL root filesystem representing the incus alpine 3.19 image.


    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslRootFileSystem alpine -Configured
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    The builtin configured Alpine root filesystem.


    -------------------------- EXAMPLE 3 --------------------------

    PS > New-WslRootFileSystem test.rootfs.tar.gz
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.21.3                   Synced test.rootfs.tar.gz
    The The root filesystem from the file.


REMARKS
    To see the examples, type: "Get-Help New-WslRootFileSystem -Examples"
    For more information, type: "Get-Help New-WslRootFileSystem -Detailed"
    For technical information, type: "Get-Help New-WslRootFileSystem -Full"
    For online help, type: "Get-Help New-WslRootFileSystem -Online"
```

## New-WslRootFileSystemHash

```text
NAME
    New-WslRootFileSystemHash

SYNOPSIS
    Creates a new FileSystem hash holder.


SYNTAX
    New-WslRootFileSystemHash [-Url] <String> [[-Algorithm] <String>] [[-Type] <String>] [<CommonParameters>]


DESCRIPTION
    The WslRootFileSystemHash object holds checksum information for one or more
    distributions in order to check it upon download and determine if the filesystem
    has been updated.

    Note that the checksums are not downloaded until the `Retrieve()` method has been
    called on the object.


PARAMETERS
    -Url <String>
        The Url where the checksums are located.

    -Algorithm <String>
        The checksum algorithm. Nowadays, we find mostly SHA256.

    -Type <String>
        Type can either be `sums` in which case the file contains one
        <checksum> <filename> pair per line, or `single` and just contains the hash for
        the file which name is the last segment of the Url minus the extension. For
        instance, if the URL is `https://.../rootfs.tar.xz.sha256`, we assume that the
        checksum it contains is for the file named `rootfs.tar.xz`.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > New-WslRootFileSystemHash https://cloud-images.ubuntu.com/wsl/noble/current/SHA256SUMS
    Creates the hash source for several files with SHA256 (default) algorithm.


    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslRootFileSystemHash https://.../rootfs.tar.xz.sha256 -Type `single`
    Creates the hash source for the rootfs.tar.xz file with SHA256 (default) algorithm.


REMARKS
    To see the examples, type: "Get-Help New-WslRootFileSystemHash -Examples"
    For more information, type: "Get-Help New-WslRootFileSystemHash -Detailed"
    For technical information, type: "Get-Help New-WslRootFileSystemHash -Full"

```

## Get-WslRootFileSystem

```text
NAME
    Get-WslRootFileSystem

SYNOPSIS
    Gets the WSL root filesystems installed on the computer and the ones available.


SYNTAX
    Get-WslRootFileSystem [[-Name] <String[]>] [[-Os] <String>] [[-State] {NotDownloaded | Synced | Outdated}] [[-Type] {Builtin | Incus | Local | Uri}] [-Configured] [-Outdated] [<CommonParameters>]


DESCRIPTION
    The Get-WslRootFileSystem cmdlet gets objects that represent the WSL root filesystems available on the computer.
    This can be the ones already synchronized as well as the Builtin filesystems available.


PARAMETERS
    -Name <String[]>
        Specifies the name of the filesystem.

    -Os <String>
        Specifies the Os of the filesystem.

    -State

    -Type
        Specifies the type of the filesystem.

    -Configured [<SwitchParameter>]

    -Outdated [<SwitchParameter>]
        Return the list of outdated root filesystems. Works mainly on Builtin
        distributions.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslRootFileSystem
       Type Os           Release                 State Name
       ---- --           -------                 ----- ----
    Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
    Builtin Arch         current                Synced arch.rootfs.tar.gz
    Builtin Debian       bookworm               Synced debian.rootfs.tar.gz
      Local Docker       unknown                Synced docker.rootfs.tar.gz
      Local Flatcar      unknown                Synced flatcar.rootfs.tar.gz
      Incus almalinux    8                      Synced incus.almalinux_8.rootfs.tar.gz
      Incus almalinux    9                      Synced incus.almalinux_9.rootfs.tar.gz
      Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
      Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
      Incus centos       9-Stream               Synced incus.centos_9-Stream.rootfs.ta...
      Incus opensuse     15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
      Incus rockylinux   9                      Synced incus.rockylinux_9.rootfs.tar.gz
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    Builtin Arch         current                Synced miniwsl.arch.rootfs.tar.gz
    Builtin Debian       bookworm               Synced miniwsl.debian.rootfs.tar.gz
    Builtin Opensuse     tumbleweed             Synced miniwsl.opensuse.rootfs.tar.gz
    Builtin Ubuntu       noble         NotDownloaded miniwsl.ubuntu.rootfs.tar.gz
      Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
    Builtin Opensuse     tumbleweed             Synced opensuse.rootfs.tar.gz
      Local Out          unknown                Synced out.rootfs.tar.gz
      Local Postgres     unknown                Synced postgres.rootfs.tar.gz
    Builtin Ubuntu       noble                Synced ubuntu.rootfs.tar.gz
    Get all WSL root filesystem.


    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslRootFileSystem -Os alpine
       Type Os           Release                 State Name
       ---- --           -------                 ----- ----
    Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
      Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
      Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    Get All Alpine root filesystems.


    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslRootFileSystem -Type Incus
    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
    Incus almalinux    8                      Synced incus.almalinux_8.rootfs.tar.gz
    Incus almalinux    9                      Synced incus.almalinux_9.rootfs.tar.gz
    Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
    Incus centos       9-Stream               Synced incus.centos_9-Stream.rootfs.ta...
    Incus opensuse     15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
    Incus rockylinux   9                      Synced incus.rockylinux_9.rootfs.tar.gz
    Get All downloaded Incus root filesystems.


REMARKS
    To see the examples, type: "Get-Help Get-WslRootFileSystem -Examples"
    For more information, type: "Get-Help Get-WslRootFileSystem -Detailed"
    For technical information, type: "Get-Help Get-WslRootFileSystem -Full"

```

## Sync-WslRootFileSystem

```text
NAME
    Sync-WslRootFileSystem

SYNOPSIS
    Synchronize locally the specified WSL root filesystem.


SYNTAX
    Sync-WslRootFileSystem [-Distribution] <String> [-Configured] [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

    Sync-WslRootFileSystem -RootFileSystem <WslRootFileSystem[]> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

    Sync-WslRootFileSystem -Path <String> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    If the root filesystem is not already present locally, downloads it from its
    original URL.


PARAMETERS
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

    -Configured [<SwitchParameter>]
        Whether the distribution is configured. This parameter is relevant for Builtin
        distributions.

    -RootFileSystem <WslRootFileSystem[]>
        The WslRootFileSystem object to process.

    -Path <String>

    -Force [<SwitchParameter>]
        Force the synchronization even if the root filesystem is already present locally.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Sync-WslRootFileSystem Alpine -Configured
    Syncs the already configured builtin Alpine root filesystem.


    -------------------------- EXAMPLE 2 --------------------------

    PS > Sync-WslRootFileSystem Alpine -Force
    Re-download the Alpine builtin root filesystem.


    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslRootFileSystem -State NotDownloaded -Os Alpine | Sync-WslRootFileSystem
    Synchronize the Alpine root filesystems not already synced


    -------------------------- EXAMPLE 4 --------------------------

    PS > New-WslRootFileSystem alpine -Configured | Sync-WslRootFileSystem | % { &wsl --import test $env:LOCALAPPDATA\Wsl\test $_ }
    Create a WSL distro from a synchronized root filesystem.


REMARKS
    To see the examples, type: "Get-Help Sync-WslRootFileSystem -Examples"
    For more information, type: "Get-Help Sync-WslRootFileSystem -Detailed"
    For technical information, type: "Get-Help Sync-WslRootFileSystem -Full"
    For online help, type: "Get-Help Sync-WslRootFileSystem -Online"
```

## Remove-WslRootFileSystem

```text
NAME
    Remove-WslRootFileSystem

SYNOPSIS
    Remove a WSL root filesystem from the local disk.


SYNTAX
    Remove-WslRootFileSystem [-Distribution] <String> [-Configured] [-WhatIf] [-Confirm] [<CommonParameters>]

    Remove-WslRootFileSystem -RootFileSystem <WslRootFileSystem[]> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    If the WSL root filesystem in synced, it will remove the tar file and its meta
    data from the disk. Builtin root filesystems will still appear as output of
    `Get-WslRootFileSystem`, but their state will be `NotDownloaded`.


PARAMETERS
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

    -Configured [<SwitchParameter>]
        Whether the root filesystem is already configured. This parameter is relevant
        only for Builtin distributions.

    -RootFileSystem <WslRootFileSystem[]>
        The WslRootFileSystem object representing the WSL root filesystem to delete.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Remove-WslRootFileSystem alpine -Configured
    Removes the builtin configured alpine root filesystem.


    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslRootFileSystem "incus:alpine:3.19" | Remove-WslRootFileSystem
    Removes the Incus alpine 3.19 root filesystem.


    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslRootFilesystem -Type Incus | Remove-WslRootFileSystem
    Removes all the Incus root filesystems present locally.


REMARKS
    To see the examples, type: "Get-Help Remove-WslRootFileSystem -Examples"
    For more information, type: "Get-Help Remove-WslRootFileSystem -Detailed"
    For technical information, type: "Get-Help Remove-WslRootFileSystem -Full"
    For online help, type: "Get-Help Remove-WslRootFileSystem -Online"
```

## Get-IncusRootFileSystem

```text
NAME
    Get-IncusRootFileSystem

SYNOPSIS
    Get the list of available Incus based root filesystems.


SYNTAX
    Get-IncusRootFileSystem [[-Name] <String[]>] [<CommonParameters>]


DESCRIPTION
    This command retrieves the list of available Incus root filesystems from the
    Canonical site: https://images.linuxcontainers.org/imagesstreams/v1/index.json


PARAMETERS
    -Name <String[]>
        List of names or wildcard based patterns to select the Os.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-IncusRootFileSystem
    Retrieve the complete list of Incus root filesystems


    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-IncusRootFileSystem alma*

    Os        Release
    --        -------
    almalinux 8
    almalinux 9

    Get all alma based filesystems.


    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-IncusRootFileSystem mint | %{ New-WslRootFileSystem "incus:$($_.Os):$($_.Release)" }

     Type Os           Release                 State Name
     ---- --           -------                 ----- ----
    Incus mint         tara            NotDownloaded incus.mint_tara.rootfs.tar.gz
    Incus mint         tessa           NotDownloaded incus.mint_tessa.rootfs.tar.gz
    Incus mint         tina            NotDownloaded incus.mint_tina.rootfs.tar.gz
    Incus mint         tricia          NotDownloaded incus.mint_tricia.rootfs.tar.gz
    Incus mint         ulyana          NotDownloaded incus.mint_ulyana.rootfs.tar.gz
    Incus mint         ulyssa          NotDownloaded incus.mint_ulyssa.rootfs.tar.gz
    Incus mint         uma             NotDownloaded incus.mint_uma.rootfs.tar.gz
    Incus mint         una             NotDownloaded incus.mint_una.rootfs.tar.gz
    Incus mint         vanessa         NotDownloaded incus.mint_vanessa.rootfs.tar.gz

    Get all mint based Incus root filesystems as WslRootFileSystem objects.


REMARKS
    To see the examples, type: "Get-Help Get-IncusRootFileSystem -Examples"
    For more information, type: "Get-Help Get-IncusRootFileSystem -Detailed"
    For technical information, type: "Get-Help Get-IncusRootFileSystem -Full"

```
