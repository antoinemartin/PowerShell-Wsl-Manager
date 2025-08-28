# Rename-WslInstance

```text

NAME
    Rename-WslInstance

SYNOPSIS
    Renames a WSL instance.


SYNTAX
    Rename-WslInstance [-Name] <String> [-NewName] <String> [<CommonParameters>]

    Rename-WslInstance -Instance <WslInstance> [-NewName] <String> [<CommonParameters>]


DESCRIPTION
    The Rename-WslInstance cmdlet renames a WSL instance to a new name.


PARAMETERS
    -Name <String>
        Specifies the name of the instance to rename.

    -Instance <WslInstance>
        Specifies the WslInstance object representing the instance to rename.

    -NewName <String>
        Specifies the new name for the instance.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Rename-WslInstance alpine alpine321
    Renames the instance named "alpine" to "alpine321".






    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslInstance -Name alpine | Rename-WslInstance -NewName alpine321
    Renames the instance named "alpine" to "alpine321".






REMARKS
    To see the examples, type: "Get-Help Rename-WslInstance -Examples"
    For more information, type: "Get-Help Rename-WslInstance -Detailed"
    For technical information, type: "Get-Help Rename-WslInstance -Full"
    For online help, type: "Get-Help Rename-WslInstance -Online"


```
