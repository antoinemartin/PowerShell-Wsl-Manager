# Rename-WslInstance

```text

NAME
    Rename-WslInstance

SYNOPSIS
    Renames a WSL distribution.


SYNTAX
    Rename-WslInstance [-Name] <String> [-NewName] <String> [<CommonParameters>]

    Rename-WslInstance -Instance <WslInstance> [-NewName] <String> [<CommonParameters>]


DESCRIPTION
    The Rename-WslInstance cmdlet renames a WSL distribution to a new name.


PARAMETERS
    -Name <String>
        Specifies the name of the distribution to rename.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Instance <WslInstance>
        Specifies the WslInstance object representing the distribution to rename.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    -NewName <String>
        Specifies the new name for the distribution.

        Required?                    true
        Position?                    2
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
    WslInstance
    You can pipe a WslInstance object retrieved by Get-WslInstance


OUTPUTS
    WslInstance
    This command outputs the renamed WSL distribution.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Rename-WslInstance alpine alpine321
    Renames the distribution named "alpine" to "alpine321".






    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslInstance -Name alpine | Rename-WslInstance -NewName alpine321
    Renames the distribution named "alpine" to "alpine321".







RELATED LINKS
    New-WslInstance



```
