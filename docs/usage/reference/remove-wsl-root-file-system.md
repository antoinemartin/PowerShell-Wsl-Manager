# Remove-WslRootFileSystem

```text

NAME
    Remove-WslRootFileSystem

SYNOPSIS
    Remove a WSL root filesystem from the local disk.


SYNTAX
    Remove-WslRootFileSystem [-Name] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]

    Remove-WslRootFileSystem -RootFileSystem <WslRootFileSystem[]> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    If the WSL root filesystem in synced, it will remove the tar file and its meta
    data from the disk. Builtin root filesystems will still appear as output of
    `Get-WslRootFileSystem`, but their state will be `NotDownloaded`.


PARAMETERS
    -Name <String[]>

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  true

    -RootFileSystem <WslRootFileSystem[]>
        The WslRootFileSystem object representing the WSL root filesystem to delete.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
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
    One or more WslRootFileSystem objects representing the WSL root filesystem to
    delete.


OUTPUTS
    The WSLRootFileSystem objects updated.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Remove-WslRootFileSystem alpine -Configured
    Removes the builtin configured alpine root filesystem.






    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslRootFileSystem "incus:alpine:3.19" | Remove-WslRootFileSystem
    Removes the Incus alpine 3.19 root filesystem.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslRootFilesystem -Type Incus | Remove-WslRootFileSystem
    Removes all the Incus root filesystems present locally.







RELATED LINKS
    Get-WslRootFileSystem
    New-WslRootFileSystem



```
