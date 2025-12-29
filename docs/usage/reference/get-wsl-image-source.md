# Get-WslImageSource

```text

NAME
    Get-WslImageSource

SYNOPSIS
    Gets the list of WSL image sources from the local cache or remote repository.


SYNTAX
    Get-WslImageSource [[-Name] <String[]>] [[-Distribution] <String>] [[-Source] {Local | Builtin | Incus | Uri | Docker | All}] [[-Type] {Builtin | Incus | Local | Uri | Docker}] [-Configured] [[-Id] <Guid[]>] [-Sync] [<CommonParameters>]


DESCRIPTION
    The Get-WslImageSource cmdlet fetches WSL image sources based on various filtering
    criteria. It first updates the cache if needed using Update-WslBuiltinImageCache,
    then retrieves matching images from the local database.

    This provides an up-to-date list of supported images that can be used to create
    WSL instances. The cmdlet implements intelligent caching with ETag support to
    reduce network requests and improve performance.


PARAMETERS
    -Name <String[]>
        Specifies the name(s) of image sources to retrieve. Supports wildcards for pattern
        matching. Can accept multiple values.

    -Distribution <String>
        Filters image sources by distribution name (e.g., "ubuntu", "alpine").

    -Source
        Specifies the source type filter for fetching root filesystems. Must be of type
        WslImageSourceType. Defaults to [WslImageSourceType]::Builtin. Valid values are:
        - Builtin: Official builtin images
        - Incus: Incus container images
        - All: All available sources

    -Type
        Specifies the exact image type to retrieve. Must be of type WslImageType.
        When specified, only images of this type will be returned and updated.

    -Configured [<SwitchParameter>]
        When specified, filters to show only configured image sources (those that have
        been set up locally).

    -Id <Guid[]>
        Filters image sources by their unique identifier(s). Can accept multiple GUIDs.

    -Sync [<SwitchParameter>]
        Forces a synchronization with the remote repository for applicable source types,
        bypassing the local cache validity check.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > Get-WslImageSource

    Gets all available builtin root filesystems, updating cache if needed.




    -------------------------- EXAMPLE 2 --------------------------

    PS > Get-WslImageSource -Name "Ubuntu*"

    Gets all image sources with names starting with "Ubuntu".




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-WslImageSource -Source Incus -Sync

    Forces a fresh download of all Incus root filesystems, ignoring local cache.




    -------------------------- EXAMPLE 4 --------------------------

    PS > Get-WslImageSource -Distribution "alpine" -Configured

    Gets all configured Alpine Linux image sources.




    -------------------------- EXAMPLE 5 --------------------------

    PS > Get-WslImageSource -Type Builtin -Name "Debian*"

    Gets all builtin Debian image sources.




REMARKS
    To see the examples, type: "Get-Help Get-WslImageSource -Examples"
    For more information, type: "Get-Help Get-WslImageSource -Detailed"
    For technical information, type: "Get-Help Get-WslImageSource -Full"
    For online help, type: "Get-Help Get-WslImageSource -Online"


```
