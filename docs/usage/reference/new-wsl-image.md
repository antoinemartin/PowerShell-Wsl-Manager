# New-WslImage

```text

NAME
    New-WslImage

SYNOPSIS
    Creates a WslImage object.


SYNTAX
    New-WslImage [-Distribution] <String> [<CommonParameters>]

    New-WslImage -Path <String> [<CommonParameters>]

    New-WslImage -File <FileInfo> [<CommonParameters>]


DESCRIPTION
    WslImage object retrieve and provide information about available root
    filesystems.


PARAMETERS
    -Distribution <String>
        The identifier of the image. It can be an already known name:
        - Arch
        - Alpine
        - Ubuntu
        - Debian

        It also can be the URL (https://...) of an existing filesystem or a
        image name saved through Export-WslInstance.

        It can also be a name in the form:

            incus:<os>:<release> (ex: incus:rockylinux:9)

        In this case, it will fetch the last version the specified image in
        https://images.linuxcontainers.org/images.

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

    PS > New-WslImage incus:alpine:3.19
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    The WSL root filesystem representing the incus alpine 3.19 image.






    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslImage alpine -Configured
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    The builtin configured Alpine root filesystem.






    -------------------------- EXAMPLE 3 --------------------------

    PS > New-WslImage test.rootfs.tar.gz
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.21.3                   Synced test.rootfs.tar.gz
    The The root filesystem from the file.






REMARKS
    To see the examples, type: "Get-Help New-WslImage -Examples"
    For more information, type: "Get-Help New-WslImage -Detailed"
    For technical information, type: "Get-Help New-WslImage -Full"
    For online help, type: "Get-Help New-WslImage -Online"


```
