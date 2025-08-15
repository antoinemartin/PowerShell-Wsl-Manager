# Stop-Wsl

```text

NAME
    Stop-Wsl

SYNOPSIS
    Stops one or more WSL distributions.


SYNTAX
    Stop-Wsl [-Name] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]

    Stop-Wsl -Distribution <WslDistribution[]> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Stop-Wsl cmdlet terminates the specified WSL distributions. This cmdlet wraps
    the functionality of "wsl.exe --terminate".


PARAMETERS
    -Name <String[]>
        Specifies the distribution names of distributions to be stopped. Wildcards are permitted.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  true

    -Distribution <WslDistribution[]>
        Specifies WslDistribution objects that represent the distributions to be stopped.

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
    WslDistribution, System.String
    You can pipe a WslDistribution object retrieved by Get-Wsl, or a string that contains
    the distribution name to this cmdlet.


OUTPUTS
    None.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Stop-Wsl Ubuntu
    Stops the Ubuntu distribution.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Stop-Wsl -Name test*
    Stops all distributions whose names start with "test".






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-Wsl -State Running | Stop-Wsl
    Stops all running distributions.






    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-Wsl Ubuntu,Debian | Stop-Wsl
    Stops the Ubuntu and Debian distributions.







RELATED LINKS



```
