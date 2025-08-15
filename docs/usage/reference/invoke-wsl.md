# Invoke-Wsl

```text

NAME
    Invoke-Wsl

SYNOPSIS
    Runs a command in one or more WSL distributions.


SYNTAX
    Invoke-Wsl [-Name <String[]>] [-User <String>] [-Arguments] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]

    Invoke-Wsl -Distribution <WslDistribution[]> [-User <String>] [-Arguments] <String[]> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Invoke-Wsl cmdlet executes the specified command on the specified distributions, and
    then exits.
    This cmdlet will raise an error if executing wsl.exe failed (e.g. there is no distribution with
    the specified name) or if the command itself failed.
    This cmdlet wraps the functionality of "wsl.exe <command>".


PARAMETERS
    -Name <String[]>
        Specifies the distribution names of distributions to run the command in. Wildcards are permitted.
        By default, the command is executed in the default distribution.

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  true

    -Distribution <WslDistribution[]>
        Specifies WslDistribution objects that represent the distributions to run the command in.
        By default, the command is executed in the default distribution.

        Required?                    true
        Position?                    named
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    -User <String>
        Specifies the name of a user in the distribution to run the command as. By default, the
        distribution's default user is used.

        Required?                    false
        Position?                    named
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Arguments <String[]>
        Command and arguments to pass to the

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
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
    You can pipe a WslDistribution object retrieved by Get-WslDistribution, or a string that contains
    the distribution name to this cmdlet.


OUTPUTS
    System.String
    This command outputs the result of the command you executed, as text.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Invoke-Wsl ls /etc
    Runs a command in the default distribution.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Invoke-Wsl -Name Ubuntu* -User root whoami
    Runs a command in all distributions whose names start with Ubuntu, as the "root" user.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-Wsl -Version 2 | Invoke-Wsl sh "-c" 'echo distro=$WSL_DISTRO_NAME,default_user=$(whoami),flavor=$(cat /etc/os-release | grep ^PRETTY | cut -d= -f 2)'
    Runs a command in all WSL2 distributions.







RELATED LINKS



```
