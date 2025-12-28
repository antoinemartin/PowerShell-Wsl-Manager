# Get-WslImage

```text

NAME
    Get-WslImage

SYNOPSIS
    Gets the WSL root filesystems installed on the computer and the ones available.


SYNTAX
    Get-WslImage [[-Name] <String[]>] [-Distribution <String>] [-Type {Local | Builtin | Incus | Uri | Docker | All}] [-State {NotDownloaded | Synced | Outdated}] [-Configured] [-Outdated] [-Source <WslImageSource>] [<CommonParameters>]

    Get-WslImage -Id <Guid[]> [<CommonParameters>]


DESCRIPTION
    The Get-WslImage cmdlet gets objects that represent the WSL root filesystems available on the computer.
    This can be the ones already synchronized as well as the Builtin filesystems available.


PARAMETERS
    -Name <String[]>
        Specifies the name of the filesystem. Supports wildcards.

    -Distribution <String>
        Specifies the linux distribution of the image.

    -Type
        Specifies the type of the filesystem source (All, Builtin, Local, Incus, Docker).

    -State
        Specifies the state of the image (NotDownloaded, Synced, Outdated).

    -Configured [<SwitchParameter>]
        Return only configured builtin images when present, or unconfigured when not present.

    -Outdated [<SwitchParameter>]
        Return the list of outdated images. Works mainly on Builtin images.

    -Source <WslImageSource>
        Filters by a specific WslImageSource object.

    -Id <Guid[]>
        Specifies one or more image IDs (GUIDs) to retrieve. This parameter is used in a separate parameter set to get images by their unique identifiers.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslImage
    Name                 Type Os           Release      Configured              State               Length
    ----                 ---- --           -------      ----------              -----               ------
    opensuse           Docker Opensuse-... 20250813     True                   Synced             107,3 MB
    docker              Local arch         3.22.1       True                   Synced             511,9 MB
    iknite              Local Alpine       3.21.3       False                  Synced             802,2 MB
    kaweezle            Local Alpine       3.21.3       False                  Synced             802,2 MB
    python              Local debian       13           True                   Synced             113,7 MB
    alpine            Builtin Alpine       3.23.2       True                   Synced              36,1 MB
    opensuse-tumb...  Builtin Opensuse-... 20251217     False                  Synced              72,3 MB
    yawsldocker-a...   Docker Alpine       3.22.1       True                   Synced             148,5 MB
    archlinux             Uri Archlinux    latest       False                  Synced             131,1 MB
    alpine             Docker alpine       edge         False                  Synced               3,5 MB
    debian-base       Builtin Debian       13           False                  Synced              48,1 MB
    arch              Builtin Arch         2025.12.01   True                   Synced             379,5 MB
    jekyll              Local Alpine       3.22.1       True                   Synced             159,0 MB
    opensuse              Uri Opensuse     tumbleweed   False                  Synced              46,4 MB

    Get all WSL root filesystem.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslImage -Distribution alpine
    Name                 Type Os           Release      Configured              State               Length
    ----                 ---- --           -------      ----------              -----               ------
    iknite              Local Alpine       3.21.3       False                  Synced             802,2 MB
    kaweezle            Local Alpine       3.21.3       False                  Synced             802,2 MB
    alpine            Builtin Alpine       3.23.2       True                   Synced              36,1 MB
    yawsldocker-a...   Docker Alpine       3.22.1       True                   Synced             148,5 MB
    jekyll              Local Alpine       3.22.1       True                   Synced             159,0 MB

    Get All Alpine root filesystems.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslImage -Type Incus
    Name             Type Os           Release      Configured              State               Length
    ----             ---- --           -------      ----------              -----               ------
    almalinux       Incus Almalinux    8            False                  Synced             110,0 MB
    almalinux       Incus Almalinux    9            False                  Synced             102,0 MB
    alpine          Incus Alpine       3.19         False                  Synced               2,9 MB
    alpine          Incus Alpine       3.20         False                  Synced               3,0 MB
    alpine          Incus Alpine       3.20         False                  Synced               3,0 MB

    Get All downloaded Incus root filesystems.




    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-WslImage -State NotDownloaded
    Get all images that are not yet downloaded.






    -------------------------- EXAMPLE 5 --------------------------

    PS > Get-WslImage -Configured
    Get all configured builtin images.






    -------------------------- EXAMPLE 6 --------------------------

    PS > Get-WslImage -Outdated
    Get all outdated images that need updating.






REMARKS
    To see the examples, type: "Get-Help Get-WslImage -Examples"
    For more information, type: "Get-Help Get-WslImage -Detailed"
    For technical information, type: "Get-Help Get-WslImage -Full"



```
