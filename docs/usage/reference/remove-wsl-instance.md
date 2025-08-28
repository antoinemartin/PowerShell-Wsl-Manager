# Remove-WslInstance

```text

NAME
    Remove-WslInstance

SYNOPSIS
    Removes WSL instance.


SYNTAX
    Remove-WslInstance [-Name] <String[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]

    Remove-WslInstance -Instance <WslInstance[]> [-KeepDirectory] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This command remove the specified instance. It also deletes the
    instance vhdx file and the directory of the instance. It's the
    equivalent of `wsl --unregister`.


PARAMETERS
    -Name <String[]>
        The name of the instance. Wildcards are permitted.

    -Instance <WslInstance[]>
        Specifies WslInstance objects that represent the instances to be removed.

    -KeepDirectory [<SwitchParameter>]
        If specified, keep the instance directory. This allows recreating
        the instance from a saved image.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Remove-WslInstance toto

    Uninstall instance named toto.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Remove-WslInstance test*

    Uninstall all instances which names start by test.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslInstance -State Stopped | Sort-Object -Property -Size -Last 1 | Remove-WslInstance

    Uninstall the largest non running instance.




REMARKS
    To see the examples, type: "Get-Help Remove-WslInstance -Examples"
    For more information, type: "Get-Help Remove-WslInstance -Detailed"
    For technical information, type: "Get-Help Remove-WslInstance -Full"
    For online help, type: "Get-Help Remove-WslInstance -Online"


```
