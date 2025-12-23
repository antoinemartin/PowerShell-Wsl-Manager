# Copyright 2022 Antoine Martin
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$WslImageSources = @{
    [WslImageType]::Incus = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json"
    [WslImageType]::Builtin = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json"
}


function Update-WslBuiltinImageCache {
    <#
    .SYNOPSIS
    Updates the cache of builtin WSL root filesystems from the remote repository.

    .DESCRIPTION
    The Update-WslBuiltinImageCache cmdlet updates the local cache of available builtin
    WSL root filesystems from the official PowerShell-Wsl-Manager repository.
    This function handles the network operations and database updates for image metadata.

    The cmdlet implements intelligent caching with ETag support to reduce network
    requests and improve performance. Cached data is valid for 24 hours unless the
    -Sync parameter is used to force a refresh.

    .PARAMETER Type
    Specifies the source type for fetching root filesystems. Must be of type
    WslImageType. Defaults to [WslImageType]::Builtin. Valid values are Builtin
    and Incus which point to their respective official repositories.

    .PARAMETER Sync
    Forces a synchronization with the remote repository, bypassing the local cache
    validity check. When specified, the cmdlet will fetch the latest data from the
    remote repository using ETag headers if available.

    .PARAMETER Force
    Forces a complete refresh ignoring both cache validity and ETag headers. When
    specified, the cmdlet will always download fresh data from the remote repository.

    .EXAMPLE
    Update-WslBuiltinImageCache

    Updates the cache for builtin root filesystems from the default repository source.

    .EXAMPLE
    Update-WslBuiltinImageCache -Type Incus -Sync

    Forces a cache update for Incus root filesystems, using ETag validation.

    .EXAMPLE
    Update-WslBuiltinImageCache -Type Builtin -Force

    Forces a complete refresh of builtin root filesystems cache, ignoring both cache
    validity and ETag headers.

    .INPUTS
    None. You cannot pipe objects to Update-WslBuiltinImageCache.

    .OUTPUTS
    System.Boolean
    Returns $true if the cache was updated with new data, $false if no update was needed
    (cache still valid or 304 Not Modified response).

    .NOTES
    - This cmdlet requires an internet connection to fetch data from the remote repository
    - The source URL is determined by the WslImageSources hashtable using the Type parameter
    - Uses HTTP ETag headers for efficient caching and conditional requests (304 responses)
    - Cache is stored in the images.db SQLite database in the images directory
    - Cache validity period is 24 hours (86400 seconds)
    - If Type is not Builtin or Incus, the function returns false without performing an update
    - Supports ShouldProcess for -WhatIf and -Confirm scenarios

    .LINK
    https://github.com/antoinemartin/PowerShell-Wsl-Manager

    .COMPONENT
    Wsl-Manager

    .FUNCTIONALITY
    WSL Distribution Management
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory = $false)]
        [WslImageType]$Type = [WslImageType]::Builtin,
        [switch]$Sync,
        [switch]$Force
    )

    if (-not ($Type -in [WslImageType]::Builtin, [WslImageType]::Incus)) {
        Write-Verbose "No builtin image source defined for type $Type. Skipping cache update."
        return $false
    }

    $Uri = [System.Uri]$WslImageSources[$Type]
    $currentTime = [int][double]::Parse((Get-Date -UFormat %s))
    $cacheValidDuration = 86400 # 24 hours in seconds

    [WslImageDatabase] $imageDb = Get-WslImageDatabase
    $dbCache = $imageDb.GetImageSourceCache($Type)

    if ($dbCache) {
        Write-Verbose "Cache lastUpdate: $($dbCache.LastUpdate) Current time $($currentTime), diff $($currentTime - $dbCache.LastUpdate)"
        if (-not $Sync) {
            if (($currentTime - $dbCache.LastUpdate) -lt $cacheValidDuration) {
                Write-Verbose "Cache is still valid, no update needed."
                return $false
            }
        } else {
            Write-Verbose "Forcing cache refresh for $Type images."
        }
    }

    try {
        $headers = @{}
        if ($dbCache) {
            if ($dbCache.Etag -and -not $Force) {
                Write-Verbose "Using cached ETag: $($dbCache.Etag)"
                $headers = @{ "If-None-Match" = $dbCache.Etag }
            }
        }

        Progress "Fetching $($Type) images from: $Uri"
        $prevProgressPreference = $global:ProgressPreference
        $global:ProgressPreference = 'SilentlyContinue'
        $response = try {
            Invoke-WebRequest -Uri $Uri -Headers $headers -UseBasicParsing
        } catch {
            $_.Exception.Response
        } finally {
            $global:ProgressPreference = $prevProgressPreference
        }

        if ($response.StatusCode -eq 304) {
            Write-Verbose "No updates found. Extending cache validity."
            if ($PSCmdlet.ShouldProcess($Type, "Updating cache timestamp.")) {
                $dbCache.LastUpdate = $currentTime
                $imageDb.UpdateImageSourceCache($Type, $dbCache)
            }
            return $false
        }

        if (-not $response.Content) {
            throw [WslManagerException]::new("The response content from $Uri is null. Please check the URL or network connection.")
        }
        $etag = $response.Headers["ETag"]
        # if etag is an array, take the first element
        if ($etag -is [array]) { # nocov
            $etag = $etag[0]
        }

        $imagesObjects =  $response.Content | ConvertFrom-Json

        if ($PSCmdlet.ShouldProcess($Type, "Updating builtin images cache.")) {
            $imageDb.SaveImageBuiltins($Type, $imagesObjects, $etag)

            $cacheData = @{
                Url        = $Uri.AbsoluteUri
                LastUpdate = $currentTime
                Etag       = $etag
            }
            $imageDb.UpdateImageSourceCache($Type, $cacheData)
        }

        Write-Verbose "Cache updated successfully."
        return $true

    } catch {
        if ($_.Exception -is [WslManagerException]) {
            throw $_.Exception
        }
        Write-Warning "Failed to update builtin root filesystems cache: $($_.Exception.Message)"
        throw
    }
}

function Get-WslImageSource {
    <#
    .SYNOPSIS
    Gets the list of WSL image sources from the local cache or remote repository.

    .DESCRIPTION
    The Get-WslImageSource cmdlet fetches WSL image sources based on various filtering
    criteria. It first updates the cache if needed using Update-WslBuiltinImageCache,
    then retrieves matching images from the local database.

    This provides an up-to-date list of supported images that can be used to create
    WSL instances. The cmdlet implements intelligent caching with ETag support to
    reduce network requests and improve performance.

    .PARAMETER Name
    Specifies the name(s) of image sources to retrieve. Supports wildcards for pattern
    matching. Can accept multiple values.

    .PARAMETER Distribution
    Filters image sources by distribution name (e.g., "ubuntu", "alpine").

    .PARAMETER Source
    Specifies the source type filter for fetching root filesystems. Must be of type
    WslImageSourceType. Defaults to [WslImageSourceType]::Builtin. Valid values are:
    - Builtin: Official builtin images
    - Incus: Incus container images
    - All: All available sources

    .PARAMETER Type
    Specifies the exact image type to retrieve. Must be of type WslImageType.
    When specified, only images of this type will be returned and updated.

    .PARAMETER Configured
    When specified, filters to show only configured image sources (those that have
    been set up locally).

    .PARAMETER Id
    Filters image sources by their unique identifier(s). Can accept multiple GUIDs.

    .PARAMETER Sync
    Forces a synchronization with the remote repository for applicable source types,
    bypassing the local cache validity check.

    .EXAMPLE
    Get-WslImageSource

    Gets all available builtin root filesystems, updating cache if needed.

    .EXAMPLE
    Get-WslImageSource -Name "Ubuntu*"

    Gets all image sources with names starting with "Ubuntu".

    .EXAMPLE
    Get-WslImageSource -Source Incus -Sync

    Forces a fresh download of all Incus root filesystems, ignoring local cache.

    .EXAMPLE
    Get-WslImageSource -Distribution "alpine" -Configured

    Gets all configured Alpine Linux image sources.

    .EXAMPLE
    Get-WslImageSource -Type Builtin -Name "Debian*"

    Gets all builtin Debian image sources.

    .INPUTS
    None. You cannot pipe objects to Get-WslImageSource.

    .OUTPUTS
    WslImageSource[]
    Returns an array of WslImageSource objects representing the available images
    that match the specified criteria.

    .NOTES
    - This cmdlet may require an internet connection to update cache from the remote repository
    - The source URL is determined by the WslImageSources hashtable using the Type parameter
    - Returns null if the request fails or if no images are found
    - Uses HTTP ETag headers for efficient caching and conditional requests (304 responses)
    - Cache is stored in the images.db SQLite database in the images directory
    - Cache validity period is 24 hours (86400 seconds)
    - Supports complex filtering with multiple parameters that can be combined

    .LINK
    https://github.com/antoinemartin/PowerShell-Wsl-Manager

    .COMPONENT
    Wsl-Manager

    .FUNCTIONALITY
    WSL Distribution Management
    #>
    [CmdletBinding()]
    [OutputType([WslImageSource[]])]
    param (
        [Parameter(Mandatory = $false)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory = $false)]
        [string]$Distribution,
        [Parameter(Mandatory = $false)]
        [WslImageSourceType]$Source = [WslImageSourceType]::Builtin,
        [Parameter(Mandatory = $false)]
        [WslImageType]$Type,
        [Parameter(Mandatory = $false)]
        [switch]$Configured,
        [Parameter(Mandatory = $false)]
        [guid[]]$Id,
        [switch]$Sync
    )

    try {

        # Fetch from database
        # TODO: should update other types (Docker, Uri) as well if requested (Sync)
        [WslImageDatabase] $imageDb = Get-WslImageDatabase

        $operators = @()
        $parameters = @{}
        $typesInUse = @()
        $typesToUpdate = @()

        [WslImageDatabase] $imageDb = Get-WslImageDatabase
        if ($PSBoundParameters.ContainsKey("Type")) {
            $typesToUpdate += $Type
            $typesInUse = @($Type.ToString())
        } else {
            if ($Source -ne [WslImageSourceType]::All) {
                foreach ($sourceType in [WslImageSourceType].GetEnumNames()) {
                    if ('All' -eq $sourceType) {
                        continue
                    }
                    if ($Source -band [WslImageSourceType]::$sourceType) {
                        $typesInUse += $sourceType
                        $typesToUpdate += $sourceType
                    }
                }
            } else {
                $typesToUpdate = @([WslImageType]::Builtin, [WslImageType]::Incus)
            }
        }

        foreach ($typeToUpdate in $typesToUpdate) {
            Update-WslBuiltinImageCache -Type $typeToUpdate -Sync:$Sync | Out-Null
        }

        if ($typesInUse.Count -gt 0) {
            $operators += "Type IN (" + (($typesInUse | ForEach-Object { "'$_'" }) -join ", ") + ")"
        }

        if ($PSBoundParameters.ContainsKey("Id")) {
            $operators += "Id IN (" + (($Id | ForEach-Object { "'$($_)'" }) -join ", ") + ")"
        }

        if ($PSBoundParameters.ContainsKey("Distribution")) {
            $operators += "Distribution = @Distribution"
            $parameters["Distribution"] = $Distribution
        }

        if ($PSBoundParameters.ContainsKey("Configured")) {
            $operators += "Configured = @Configured"
            $parameters["Configured"] = if ($Configured.IsPresent) { 'TRUE' } else { 'FALSE' }
        }

        if ($Name.Length -gt 0) {
            $operators += ($Name | ForEach-Object { "(Name GLOB '$($_)')" }) -join " OR "
        }
        $whereClause = $operators -join " AND "
        Write-Verbose "Get-WslImageSource: WHERE $whereClause with parameters $($parameters | ConvertTo-Json -Compress)"
        $fileSystems = $imageDb.GetImageSources($whereClause, $parameters)

        return $fileSystems | ForEach-Object { [WslImageSource]::new($_) }

    } catch {
        if ($_.Exception -is [WslManagerException] -and -not ($_.Exception -is [WslImageSourceNotFoundException])) {
            throw $_.Exception
        }
        Write-Warning "Failed to retrieve image sources: $($_.Exception.Message)"
        # return $null
    }

}

function Remove-WslImageSource {
    <#
    .SYNOPSIS
    Removes one or more WSL image sources from the local cache.

    .DESCRIPTION
    The Remove-WslImageSource function removes WSL image sources from the local image
    database cache. It can remove sources by providing WslImageSource objects directly,
    by specifying source names with optional type filtering, or by GUID. The function
    only removes cached sources and will skip non-cached sources with a warning message.

    The function supports the ShouldProcess pattern, allowing -WhatIf and -Confirm
    parameters for safe operation.

    .PARAMETER ImageSource
    Specifies one or more WslImageSource objects to remove. This parameter accepts
    pipeline input and is used with the 'Source' parameter set.

    .PARAMETER Name
    Specifies the name(s) of the image source(s) to remove. Supports wildcards for
    pattern matching. This parameter is used with the 'Name' parameter set and is
    mandatory when using this parameter set.

    .PARAMETER Type
    Specifies the type of WSL image to filter by when using the Name parameter.
    This parameter is optional and only applies to the 'Name' parameter set.

    .PARAMETER Id
    Specifies the unique identifier (GUID) of the image source to remove. This
    parameter is mandatory when using the 'Id' parameter set.

    .INPUTS
    WslImageSource[]
    You can pipe WslImageSource objects to this function.

    .OUTPUTS
    WslImageSource
    Returns the WslImageSource object that was removed, with its Id set to Empty GUID.

    .EXAMPLE
    Remove-WslImageSource -Name "Ubuntu*"

    Removes all cached WSL image sources with names starting with "Ubuntu".

    .EXAMPLE
    Get-WslImageSource -Name "MyImage" | Remove-WslImageSource

    Gets a specific image source and pipes it to Remove-WslImageSource for removal.

    .EXAMPLE
    Remove-WslImageSource -Name "Alpine" -Type Builtin

    Removes the cached builtin WSL image source named "Alpine".

    .EXAMPLE
    Remove-WslImageSource -Id "12345678-1234-1234-1234-123456789012"

    Removes the image source with the specified GUID.

    .EXAMPLE
    Remove-WslImageSource -Name "Debian*" -WhatIf

    Shows what would happen if the command runs without actually removing anything.

    .NOTES
    - The function supports the ShouldProcess pattern for confirmation prompts
    - Only cached image sources will be removed; non-cached sources are skipped with a warning
    - Uses the WSL Image Database to perform the actual removal operation
    - When using the Id parameter, searches across all source types
    - Returns the removed image source objects with their Id property set to Empty GUID
    #>
    [CmdletBinding(SupportsShouldProcess=$true)]
    param (
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = 'Source', Position = 0)]
        [WslImageSource[]]$ImageSource,
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [WslImageType]$Type,
        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [Guid]$Id
    )

    process {
        [WslImageDatabase] $imageDb = Get-WslImageDatabase

        if ($PSCmdlet.ParameterSetName -eq 'Name') {
            $ImageSource = Get-WslImageSource -Name $Name -Type $Type
        }
        elseif ($PSCmdlet.ParameterSetName -eq 'Id') {
            $ImageSource = Get-WslImageSource -Id $Id -Source All
        }

        foreach ($source in $ImageSource) {
            if ($PSCmdlet.ShouldProcess("WslImageSource: $($source.Name)", "Removing image source")) {
                if (-not $source.IsCached) {
                    Write-Warning "Image source $($source.Name) is not cached locally. Skipping removal."
                    continue
                }
                $imageDb.RemoveImageSource($source.Id)
                $source.Id = [Guid]::Empty
                $source
            }
        }
    }
}
