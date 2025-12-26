# New-WslImage

```text

NAME
    New-WslImage

SYNOPSIS
    Creates a WslImage object.


SYNTAX
    New-WslImage [-Source] <WslImageSource[]> [<CommonParameters>]

    New-WslImage -Name <String> [<CommonParameters>]

    New-WslImage -Uri <Uri> [<CommonParameters>]

    New-WslImage -File <FileInfo> [<CommonParameters>]


DESCRIPTION
    WslImage object retrieve and provide information about available root
    filesystems.


PARAMETERS
    -Source <WslImageSource[]>
        A WslImageSource object representing the image source to create a local image from.

    -Name <String>
        The identifier of the image. It can be an already known name:
        - Arch
        - Alpine
        - Ubuntu
        - Debian

        It also can be the URL (https://...) of an existing filesystem or a
        image name saved through Export-WslInstance.

        It can also be a URL in the form:

            incus://<os>#<release> (ex: incus://rockylinux#9)

        In this case, it will fetch the last version the specified image in
        https://images.linuxcontainers.org/images.

    -Uri <Uri>
        A URI object representing the location of the root filesystem.

    -File <FileInfo>
        A FileInfo object of the compressed root filesystem.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > New-WslImage -Name "incus://alpine#3.19"
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    Creates a WSL root filesystem from the incus alpine 3.19 image.






    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslImage -Name "alpine"
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.19                   Synced alpine.rootfs.tar.gz
    Creates a WSL root filesystem from the builtin Alpine image.






    -------------------------- EXAMPLE 3 --------------------------

    PS > New-WslImage -File (Get-Item "C:\temp\test.rootfs.tar.gz")
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Local   Alpine       3.21.3                 Synced test.rootfs.tar.gz
    Creates a WSL root filesystem from a local file.






    -------------------------- EXAMPLE 4 --------------------------

    PS > New-WslImage -Name "C:\temp\test.rootfs.tar.gz"
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Local   Alpine       3.21.3                 Synced test.rootfs.tar.gz
    Creates a WSL root filesystem from a local file without requiring a FileInfo object.






    -------------------------- EXAMPLE 5 --------------------------

    PS > Get-WslImageSource | New-WslImage
    Creates WslImage objects from all available image sources.






REMARKS
    To see the examples, type: "Get-Help New-WslImage -Examples"
    For more information, type: "Get-Help New-WslImage -Detailed"
    For technical information, type: "Get-Help New-WslImage -Full"
    For online help, type: "Get-Help New-WslImage -Online"


```
