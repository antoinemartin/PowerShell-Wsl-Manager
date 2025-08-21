# Invoke-WslInstance

```text

NAME
    Invoke-WslInstance

SYNOPSIS
    Runs a command in one or more WSL distributions.


SYNTAX
    Invoke-WslInstance [-In <String[]>] [-User <String>] [[-Arguments] <String[]>] [-WhatIf] [-Confirm] [<CommonParameters>]

    Invoke-WslInstance -Instance <WslInstance[]> [-User <String>] [[-Arguments] <String[]>] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Invoke-WslInstance cmdlet executes the specified command on the specified distributions, and
    then exits.
    This cmdlet will raise an error if executing wsl.exe failed (e.g. there is no distribution with
    the specified name) or if the command itself failed.
    This cmdlet wraps the functionality of "wsl.exe <command>".


PARAMETERS
    -In <String[]>
        Specifies the distribution names of distributions to run the command in. Wildcards are permitted.
        By default, the command is executed in the default distribution.

    -Instance <WslInstance[]>
        Specifies WslInstance objects that represent the distributions to run the command in.
        By default, the command is executed in the default distribution.

    -User <String>
        Specifies the name of a user in the distribution to run the command as. By default, the
        distribution's default user is used.

    -Arguments <String[]>
        Command and arguments to pass to the

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Invoke-WslInstance ls /etc
    Runs a command in the default distribution.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Invoke-WslInstance -In Ubuntu* -User root whoami
    Runs a command in all distributions whose names start with Ubuntu, as the "root" user.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslInstance -Version 2 | Invoke-WslInstance sh "-c" 'echo distro=$WSL_DISTRO_NAME,default_user=$(whoami),flavor=$(cat /etc/os-release | grep ^PRETTY | cut -d= -f 2)'
    Runs a command in all WSL2 distributions.






REMARKS
    To see the examples, type: "Get-Help Invoke-WslInstance -Examples"
    For more information, type: "Get-Help Invoke-WslInstance -Detailed"
    For technical information, type: "Get-Help Invoke-WslInstance -Full"



```
