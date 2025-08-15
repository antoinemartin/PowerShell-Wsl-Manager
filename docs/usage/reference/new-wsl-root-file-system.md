# New-WslRootFileSystem

```text

NAME
    New-WslRootFileSystem

SYNOPSIS
    Creates a WslRootFileSystem object.


SYNTAX
    New-WslRootFileSystem [-Distribution] <String> [<CommonParameters>]

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

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Path <String>
        The path of the root filesystem. Should be a file ending with `rootfs.tar.gz`.
        It will try to extract the OS and Release from the filename (in /etc/os-release).

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    -File <FileInfo>
        A FileInfo object of the compressed root filesystem.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS

OUTPUTS

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







RELATED LINKS
    Get-WslRootFileSystem



```
