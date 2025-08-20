# Set-WslDefaultUid

```text

NAME
    Set-WslDefaultUid

SYNOPSIS
    Sets the default UID for one or more WSL distributions.


SYNTAX
    Set-WslDefaultUid [-Name] <String[]> [-Uid] <Int32> [-WhatIf] [-Confirm] [<CommonParameters>]

    Set-WslDefaultUid [-Instance] <WslInstance[]> [-Uid] <Int32> [-WhatIf] [-Confirm] [<CommonParameters>]


DESCRIPTION
    The Set-WslDefaultUid cmdlet sets the default user ID (UID) for the specified WSL distributions.
    This determines which user account is used when launching the distribution without specifying a user.


PARAMETERS
    -Name <String[]>
        Specifies the distribution names of distributions to set the default UID for. Wildcards are permitted.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  true

    -Instance <WslInstance[]>
        Specifies WslInstance objects that represent the distributions to set the default UID for.

        Required?                    true
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  false

    -Uid <Int32>
        Specifies the user ID to set as default. Common values are 0 (root) or 1000 (first regular user).

        Required?                    true
        Position?                    2
        Default value                0
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
    WslInstance, System.String
    You can pipe a WslInstance object retrieved by Get-WslInstance, or a string that contains
    the distribution name to this cmdlet.


OUTPUTS
    None.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Set-WslDefaultUid -Name Ubuntu -Uid 1000
    Sets the default UID to 1000 for the Ubuntu distribution.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Set-WslDefaultUid -Name test* -Uid 0
    Sets the default UID to 0 (root) for all distributions whose names start with "test".






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslInstance -Version 2 | Set-WslDefaultUid -Uid 1000
    Sets the default UID to 1000 for all WSL2 distributions.






    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-WslInstance Ubuntu,Debian | Set-WslDefaultUid -Uid 1000
    Sets the default UID to 1000 for the Ubuntu and Debian distributions.







RELATED LINKS



```
