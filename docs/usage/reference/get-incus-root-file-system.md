# Get-IncusRootFileSystem

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

        Required?                    false
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  true

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS

OUTPUTS

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





RELATED LINKS



```
