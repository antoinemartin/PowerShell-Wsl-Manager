# Set-WslDefaultInstance

```text

NAME
    Set-WslDefaultInstance

SYNOPSIS
    Sets the default WSL instance.


SYNTAX
    Set-WslDefaultInstance [-Name] <String> [-WhatIf] [-Confirm] [<CommonParameters>]

    Set-WslDefaultInstance -Instance <WslInstance> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION


PARAMETERS
    -Name <String>
        The name of the WSL instance to set as default.

    -Instance <WslInstance>
        The WSL instance object to set as default. Must be a WslInstance object.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Set-WslDefaultInstance -Name "alpine"
    Sets the default WSL instance to "alpine".






    -------------------------- EXAMPLE 2 --------------------------

    PS > Set-WslDefaultInstance -Instance $myInstance
    Sets the default WSL instance to the specified instance object.






REMARKS
    To see the examples, type: "Get-Help Set-WslDefaultInstance -Examples"
    For more information, type: "Get-Help Set-WslDefaultInstance -Detailed"
    For technical information, type: "Get-Help Set-WslDefaultInstance -Full"



```
