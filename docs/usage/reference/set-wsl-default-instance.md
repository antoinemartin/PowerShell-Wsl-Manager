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

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Instance <WslInstance>
        The WSL instance object to set as default.

        Required?                    true
        Position?                    named
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

OUTPUTS

    -------------------------- EXAMPLE 1 --------------------------

    PS > Set-WslDefaultInstance -Name "alpine"
    Sets the default WSL instance to "alpine".






    -------------------------- EXAMPLE 2 --------------------------

    PS > Set-WslDefaultInstance -Instance $myInstance
    Sets the default WSL instance to the specified instance object.







RELATED LINKS



```
