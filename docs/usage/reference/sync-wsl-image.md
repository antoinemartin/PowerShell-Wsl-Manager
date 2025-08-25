# Sync-WslImage

```text

NAME
    Sync-WslImage

SYNOPSIS
    Synchronize locally the specified WSL root filesystem.


SYNTAX
    Sync-WslImage [-Name] <String[]> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

    Sync-WslImage -Image <WslImage[]> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]

    Sync-WslImage -Path <String> [-Force] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    If the root filesystem is not already present locally, downloads it from its
    original URL.


PARAMETERS
    -Name <String[]>
        The identifier of the image. It can be an already known name:
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

        It can also designate a docker image in the form:

            docker://<registry>/<image>#<tag> (ex: docker://ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine:latest)

        NOTE: Currently, only images with a single layer are supported.

    -Image <WslImage[]>
        The WslImage object to process.

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

    PS > Sync-WslImage Alpine -Configured
    Syncs the already configured builtin Alpine root filesystem.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Sync-WslImage Alpine -Force
    Re-download the Alpine builtin root filesystem.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslImage -State NotDownloaded -Os Alpine | Sync-WslImage
    Synchronize the Alpine root filesystems not already synced






    -------------------------- EXAMPLE 4 --------------------------

    PS > New-WslImage alpine -Configured | Sync-WslImage | % { &wsl --import test $env:LOCALAPPDATA\Wsl\test $_ }
    Create a WSL distro from a synchronized root filesystem.






REMARKS
    To see the examples, type: "Get-Help Sync-WslImage -Examples"
    For more information, type: "Get-Help Sync-WslImage -Detailed"
    For technical information, type: "Get-Help Sync-WslImage -Full"
    For online help, type: "Get-Help Sync-WslImage -Online"


```
