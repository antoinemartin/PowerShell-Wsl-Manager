# Get-WslImage

```text

NAME
    Get-WslImage

SYNOPSIS
    Gets the WSL root filesystems installed on the computer and the ones available.


SYNTAX
    Get-WslImage [[-Name] <String[]>] [-Os <String>] [-Type {Local | Builtin | Incus | Uri | Docker | All}] [-State {NotDownloaded | Synced | Outdated}] [-Configured] [-Outdated] [-Source <WslImageSource>] [<CommonParameters>]

    Get-WslImage -Id <Guid[]> [<CommonParameters>]


DESCRIPTION
    The Get-WslImage cmdlet gets objects that represent the WSL root filesystems available on the computer.
    This can be the ones already synchronized as well as the Builtin filesystems available.


PARAMETERS
    -Name <String[]>
        Specifies the name of the filesystem. Supports wildcards.

    -Os <String>
        Specifies the operating system of the filesystem.

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

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslImage
       Type Os           Release                 State Name
       ---- --           -------                 ----- ----
    Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
    Builtin Arch         current                Synced arch.rootfs.tar.gz
    Builtin Debian       bookworm               Synced debian.rootfs.tar.gz
      Local Docker       unknown                Synced docker.rootfs.tar.gz
      Local Flatcar      unknown                Synced flatcar.rootfs.tar.gz
    Incus almalinux      8                      Synced incus.almalinux_8.rootfs.tar.gz
    Incus almalinux      9                      Synced incus.almalinux_9.rootfs.tar.gz
    Incus alpine         3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    Incus alpine         edge                   Synced incus.alpine_edge.rootfs.tar.gz
    Incus centos         9-Stream               Synced incus.centos_9-Stream.Image.ta...
    Incus opensuse       15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
    Incus rockylinux     9                      Synced incus.rockylinux_9.rootfs.tar.gz
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    Builtin Arch         current                Synced miniwsl.arch.rootfs.tar.gz
    Builtin Debian       bookworm               Synced miniwsl.debian.rootfs.tar.gz
    Builtin Opensuse     tumbleweed             Synced miniwsl.opensuse.rootfs.tar.gz
    Builtin Ubuntu       noble           NotDownloaded miniwsl.ubuntu.rootfs.tar.gz
      Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
    Builtin Opensuse     tumbleweed             Synced opensuse.rootfs.tar.gz
      Local Out          unknown                Synced out.rootfs.tar.gz
      Local Postgres     unknown                Synced postgres.rootfs.tar.gz
    Builtin Ubuntu       noble                  Synced ubuntu.rootfs.tar.gz
    Get all WSL root filesystem.






    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslImage -Os alpine
       Type Os           Release                 State Name
       ---- --           -------                 ----- ----
    Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
      Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
      Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    Get All Alpine root filesystems.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslImage -Type Incus
    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
    Incus almalinux    8                      Synced incus.almalinux_8.rootfs.tar.gz
    Incus almalinux    9                      Synced incus.almalinux_9.rootfs.tar.gz
    Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
    Incus centos       9-Stream               Synced incus.centos_9-Stream.Image.ta...
    Incus opensuse     15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
    Incus rockylinux   9                      Synced incus.rockylinux_9.rootfs.tar.gz
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
