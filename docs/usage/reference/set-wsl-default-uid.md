# Set-WslDefaultUid

```text

NAME
    Set-WslDefaultUid

SYNOPSIS
    Sets the default UID for one or more WSL instances.


SYNTAX
    Set-WslDefaultUid [-Name] <String[]> [-Uid] <Int32> [-WhatIf] [-Confirm] [<CommonParameters>]

    Set-WslDefaultUid [-Instance] <WslInstance[]> [-Uid] <Int32> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Set-WslDefaultUid cmdlet sets the default user ID (UID) for the specified WSL instances.
    This determines which user account is used when launching the instance without specifying a user.


PARAMETERS
    -Name <String[]>
        Specifies the instance names of instances to set the default UID for. Wildcards are permitted.

    -Instance <WslInstance[]>
        Specifies WslInstance objects that represent the instances to set the default UID for.

    -Uid <Int32>
        Specifies the user ID to set as default. Common values are 0 (root) or 1000 (first regular user).

    -WhatIf [<SwitchParameter>]

    -Confirm [<SwitchParameter>]

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Set-WslDefaultUid -Name Ubuntu -Uid 1000
    Sets the default UID to 1000 for the Ubuntu instance.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Set-WslDefaultUid -Name test* -Uid 0
    Sets the default UID to 0 (root) for all instances whose names start with "test".






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslInstance -Version 2 | Set-WslDefaultUid -Uid 1000
    Sets the default UID to 1000 for all WSL2 instances.






    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-WslInstance Ubuntu,Debian | Set-WslDefaultUid -Uid 1000
    Sets the default UID to 1000 for the Ubuntu and Debian instances.






REMARKS
    To see the examples, type: "Get-Help Set-WslDefaultUid -Examples"
    For more information, type: "Get-Help Set-WslDefaultUid -Detailed"
    For technical information, type: "Get-Help Set-WslDefaultUid -Full"



```
