# Invoke-WslConfigure

```text

NAME
    Invoke-WslConfigure

SYNOPSIS
    Configures a WSL instance.


SYNTAX
    Invoke-WslConfigure [-Name] <String> [[-Uid] <Int32>] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This function runs the configuration script inside the specified WSL instance
    to create a non-root user.


PARAMETERS
    -Name <String>
        The name of the WSL instance to configure.

    -Uid <Int32>
        The user ID to set as the default for the instance.

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

REMARKS
    To see the examples, type: "Get-Help Invoke-WslConfigure -Examples"
    For more information, type: "Get-Help Invoke-WslConfigure -Detailed"
    For technical information, type: "Get-Help Invoke-WslConfigure -Full"



```
