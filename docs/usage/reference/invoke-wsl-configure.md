# Invoke-WslConfigure

```text

NAME
    Invoke-WslConfigure

SYNOPSIS
    Configures a WSL distribution.


SYNTAX
    Invoke-WslConfigure [-Name] <String> [[-Uid] <Int32>] [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    This function runs the configuration script inside the specified WSL distribution
    to create a non-root user.


PARAMETERS
    -Name <String>
        The name of the WSL distribution to configure.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Uid <Int32>
        The user ID to set as the default for the distribution.

        Required?                    false
        Position?                    2
        Default value                1000
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


RELATED LINKS



```
