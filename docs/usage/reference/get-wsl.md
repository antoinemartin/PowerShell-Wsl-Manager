# Get-Wsl

```text

NAME
    Get-Wsl

SYNOPSIS
    Gets the WSL distributions installed on the computer.


SYNTAX
    Get-Wsl [[-Name] <String[]>] [-Default] [[-State] {Stopped | Running | Installing | Uninstalling | Converting}] [[-Version] <Int32>] [<CommonParameters>]


DESCRIPTION
    The Get-Wsl cmdlet gets objects that represent the WSL distributions on the computer.
    This cmdlet wraps the functionality of "wsl.exe --list --verbose".


PARAMETERS
    -Name <String[]>
        Specifies the distribution names of distributions to be retrieved. Wildcards are permitted. By
        default, this cmdlet gets all of the distributions on the computer.

        Required?                    false
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  true

    -Default [<SwitchParameter>]
        Indicates that this cmdlet gets only the default distribution. If this is combined with other
        parameters such as Name, nothing will be returned unless the default distribution matches all the
        conditions. By default, this cmdlet gets all of the distributions on the computer.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -State
        Indicates that this cmdlet gets only distributions in the specified state (e.g. Running). By
        default, this cmdlet gets all of the distributions on the computer.

        Required?                    false
        Position?                    2
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Version <Int32>
        Indicates that this cmdlet gets only distributions that are the specified version. By default,
        this cmdlet gets all of the distributions on the computer.

        Required?                    false
        Position?                    3
        Default value                0
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS
    System.String
    You can pipe a distribution name to this cmdlet.


OUTPUTS
    WslDistribution
    The cmdlet returns objects that represent the distributions on the computer.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-Wsl
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Ubuntu-18.04 Running       1   False
    Alpine       Running       2   False
    Debian       Stopped       1   False
    Get all WSL distributions.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-Wsl -Default
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Get the default distribution.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-Wsl -Version 2 -State Running
    Name           State Version Default
    ----           ----- ------- -------
    Alpine       Running       2   False
    Get running WSL2 distributions.






    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-Wsl Ubuntu* | Stop-WslDistribution
    Terminate all distributions that start with Ubuntu






    -------------------------- EXAMPLE 5 --------------------------

    PS > Get-Content distributions.txt | Get-Wsl
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Debian       Stopped       1   False
    Use the pipeline as input.







RELATED LINKS



```
