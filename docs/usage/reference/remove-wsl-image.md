# Remove-WslImage

```text

NAME
    Remove-WslImage

SYNOPSIS
    Remove a WSL root filesystem from the local disk.


SYNTAX
    Remove-WslImage [-Name] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]

    Remove-WslImage -Image <WslImage[]> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    If the WSL root filesystem in synced, it will remove the tar file and its meta
    data from the disk. Builtin root filesystems will still appear as output of
    `Get-WslImage`, but their state will be `NotDownloaded`.


PARAMETERS
    -Name <String[]>

    -Image <WslImage[]>
        The WslImage object representing the WSL root filesystem to delete.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Remove-WslImage alpine -Configured
    Removes the builtin configured alpine root filesystem.






    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslImage "incus:alpine:3.19" | Remove-WslImage
    Removes the Incus alpine 3.19 root filesystem.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslImage -Type Incus | Remove-WslImage
    Removes all the Incus root filesystems present locally.






REMARKS
    To see the examples, type: "Get-Help Remove-WslImage -Examples"
    For more information, type: "Get-Help Remove-WslImage -Detailed"
    For technical information, type: "Get-Help Remove-WslImage -Full"
    For online help, type: "Get-Help Remove-WslImage -Online"


```
