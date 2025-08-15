# Get-WslRootFileSystem

```text

NAME
    Get-WslRootFileSystem

SYNOPSIS
    Gets the WSL root filesystems installed on the computer and the ones available.


SYNTAX
    Get-WslRootFileSystem [[-Name] <String[]>] [[-Os] <String>] [[-State] {NotDownloaded | Synced | Outdated}] [[-Type] {Builtin | Incus | Local | Uri}] [-Configured] [-Outdated] [<CommonParameters>]


DESCRIPTION
    The Get-WslRootFileSystem cmdlet gets objects that represent the WSL root filesystems available on the computer.
    This can be the ones already synchronized as well as the Builtin filesystems available.


PARAMETERS
    -Name <String[]>
        Specifies the name of the filesystem.

        Required?                    false
        Position?                    1
        Default value
        Accept pipeline input?       true (ByValue)
        Aliases
        Accept wildcard characters?  true

    -Os <String>
        Specifies the Os of the filesystem.

        Required?                    false
        Position?                    2
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -State

        Required?                    false
        Position?                    3
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Type
        Specifies the type of the filesystem.

        Required?                    false
        Position?                    4
        Default value
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Configured [<SwitchParameter>]

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    -Outdated [<SwitchParameter>]
        Return the list of outdated root filesystems. Works mainly on Builtin
        distributions.

        Required?                    false
        Position?                    named
        Default value                False
        Accept pipeline input?       false
        Aliases
        Accept wildcard characters?  false

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

INPUTS
    System.String
    You can pipe a distribution name to this cmdlet.


OUTPUTS
    WslRootFileSystem
    The cmdlet returns objects that represent the WSL root filesystems on the computer.


    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslRootFileSystem
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
    Incus centos         9-Stream               Synced incus.centos_9-Stream.rootfs.ta...
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

    PS > Get-WslRootFileSystem -Os alpine
       Type Os           Release                 State Name
       ---- --           -------                 ----- ----
    Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
      Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
      Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    Get All Alpine root filesystems.






    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslRootFileSystem -Type Incus
    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
    Incus almalinux    8                      Synced incus.almalinux_8.rootfs.tar.gz
    Incus almalinux    9                      Synced incus.almalinux_9.rootfs.tar.gz
    Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
    Incus centos       9-Stream               Synced incus.centos_9-Stream.rootfs.ta...
    Incus opensuse     15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
    Incus rockylinux   9                      Synced incus.rockylinux_9.rootfs.tar.gz
    Get All downloaded Incus root filesystems.







RELATED LINKS



```
