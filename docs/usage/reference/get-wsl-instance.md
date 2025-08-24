# Get-WslInstance

```text

NAME
    Get-WslInstance

SYNOPSIS
    Gets the WSL instances installed on the computer.


SYNTAX
    Get-WslInstance [[-Name] <String[]>] [-Default] [[-State] {Stopped | Running | Installing | Uninstalling | Converting}] [[-Version] <Int32>] [<CommonParameters>]


DESCRIPTION
    The Get-WslInstance cmdlet gets objects that represent the WSL instances on the computer.
    This cmdlet wraps the functionality of "wsl.exe --list --verbose".


PARAMETERS
    -Name <String[]>
        Specifies the instance names of instances to be retrieved. Wildcards are permitted. By
        default, this cmdlet gets all of the instances on the computer.

    -Default [<SwitchParameter>]
        Indicates that this cmdlet gets only the default instance. If this is combined with other
        parameters such as Name, nothing will be returned unless the default instance matches all the
        conditions. By default, this cmdlet gets all of the instances on the computer.

    -State
        Indicates that this cmdlet gets only instances in the specified state (e.g. Running). By
        default, this cmdlet gets all of the instances on the computer.

    -Version <Int32>
        Indicates that this cmdlet gets only instances that are the specified version. By default,
        this cmdlet gets all of the instances on the computer.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-Wsl
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Ubuntu-18.04 Running       1   False
    Alpine       Running       2   False
    Debian       Stopped       1   False
    Get all WSL instances.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslInstance -Default
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Get the default instance.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslInstance -Version 2 -State Running
    Name           State Version Default
    ----           ----- ------- -------
    Alpine       Running       2   False
    Get running WSL2 instances.






    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-WslInstance Ubuntu* | Stop-WslInstance
    Terminate all instances that start with Ubuntu






    -------------------------- EXAMPLE 5 --------------------------

    PS > Get-Content instances.txt | Get-WslInstance
    Name           State Version Default
    ----           ----- ------- -------
    Ubuntu       Stopped       2    True
    Debian       Stopped       1   False
    Use the pipeline as input.






REMARKS
    To see the examples, type: "Get-Help Get-WslInstance -Examples"
    For more information, type: "Get-Help Get-WslInstance -Detailed"
    For technical information, type: "Get-Help Get-WslInstance -Full"



```
