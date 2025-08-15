# Rename-Wsl

```text

NAME
    Rename-Wsl

SYNOPSIS
    Renames a WSL distribution.


SYNTAX
    Rename-Wsl [-Name] <String> [-NewName] <String> [<CommonParameters>]

    Rename-Wsl -Distribution <WslDistribution> [-NewName] <String> [<CommonParameters>]


DESCRIPTION
    The Rename-Wsl cmdlet renames a WSL distribution to a new name.


PARAMETERS
    -Name <String>
        Specifies the name of the distribution to rename.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Distribution <WslDistribution>

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
    WslDistribution
    You can pipe a WslDistribution object retrieved by Get-WslDistribution


OUTPUTS
    WslDistribution
    This command outputs the renamed WSL distribution.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Rename-Wsl alpine alpine321
    Renames the distribution named "alpine" to "alpine321".






    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-Wsl -Name alpine | Rename-Wsl -NewName alpine321
    Renames the distribution named "alpine" to "alpine321".







RELATED LINKS
    Install-Wsl



```
