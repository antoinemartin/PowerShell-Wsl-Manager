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
    [WslImageSource]::Incus = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json"
    [WslImageSource]::Builtins = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json"
}

[Diagnostics.CodeAnalysis.ExcludeFromCodeCoverage()]
$WslImageCacheFileCache = @{}

function Get-WslBuiltinImage {
    <#
    .SYNOPSIS
    Gets the list of builtin WSL root filesystems from the remote repository.

    .DESCRIPTION
    The Get-WslBuiltinImage cmdlet fetches the list of available builtin
    WSL root filesystems from the official PowerShell-Wsl-Manager repository.
    This provides an up-to-date list of supported distributions that can be used
    to create WSL distributions.

    The cmdlet downloads a JSON file from the remote repository and converts it
    into WslImage objects that can be used with other Wsl-Manager commands.
    The cmdlet implements intelligent caching with ETag support to reduce network
    requests and improve performance. Cached data is valid for 24 hours unless the
    -Sync parameter is used to force a refresh.

    .PARAMETER Source
    Specifies the source type for fetching root filesystems. Must be of type
    WslImageSource. Defaults to [WslImageSource]::Builtins
    which points to the official repository of builtin distributions.

    .PARAMETER Sync
    Forces a synchronization with the remote repository, bypassing the local cache.
    When specified, the cmdlet will always fetch the latest data from the remote
    repository regardless of cache validity period and ETag headers.

    .EXAMPLE
    Get-WslBuiltinImage

    Gets all available builtin root filesystems from the default repository source.

    .EXAMPLE
    Get-WslBuiltinImage -Source Builtins

    Explicitly gets builtin root filesystems from the builtins source.

    .EXAMPLE
    Get-WslBuiltinImage -Sync

    Forces a fresh download of all builtin root filesystems, ignoring local cache
    and ETag headers.

    .INPUTS
    None. You cannot pipe objects to Get-WslBuiltinImage.

    .OUTPUTS
    WslImage[]
    Returns an array of WslImage objects representing the available
    builtin distributions.

    .NOTES
    - This cmdlet requires an internet connection to fetch data from the remote repository
    - The source URL is determined by the WslImageSources hashtable using the Source parameter
    - Returns null if the request fails or if no distributions are found
    - The Progress function is used to display download status during network operations
    - Uses HTTP ETag headers for efficient caching and conditional requests (304 responses)
    - Cache is stored in the WslImage base path with filename from the URI
    - Cache validity period is 24 hours (86400 seconds)
    - In-memory cache (WslImageCacheFileCache) is used alongside file-based cache
    - ETag support allows for efficient cache validation without re-downloading unchanged data

    .LINK
    https://github.com/antoinemartin/PowerShell-Wsl-Manager

    .COMPONENT
    Wsl-Manager

    .FUNCTIONALITY
    WSL Distribution Management
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [WslImageSource]$Source = [WslImageSource]::Builtins,
        [switch]$Sync
    )

    $Uri = [System.Uri]$WslImageSources[$Source]
    $CacheFilename = $Uri.Segments[-1]
    $cacheFile = Join-Path -Path ([WslImage]::BasePath) -ChildPath $CacheFilename
    $currentTime = [int][double]::Parse((Get-Date -UFormat %s))
    $cacheValidDuration = 86400 # 24 hours in seconds

    $hasCacheFile = $WslImageCacheFileCache.ContainsKey($Source) -or (Test-Path $cacheFile)
    # Populate cache if not already done
    if ($hasCacheFile -and -not $WslImageCacheFileCache.ContainsKey($Source)) {
        $cache = Get-Content -Path $cacheFile | ConvertFrom-Json
        $WslImageCacheFileCache[$Source] = $cache
        $cache.builtins = $cache.builtins | ForEach-Object {
            [WslImage]::new($_)
        }
    }

    if (-not $Sync -and $hasCacheFile) {
        $cache = $WslImageCacheFileCache[$Source]
        Write-Verbose "Cache lastUpdate: $($cache.lastUpdate) Current time $($currentTime), diff $($currentTime - $cache.lastUpdate)"
        if (($currentTime - $cache.lastUpdate) -lt $cacheValidDuration -and $null -ne $cache.builtins) {
            return $cache.builtins
        }
    }

    try {
        $headers = @{}
        if ($hasCacheFile) {
            $cache = $WslImageCacheFileCache[$Source]
            if ($cache.etag) {
                $headers = @{ "If-None-Match" = $cache.etag[0] }
            }
        }

        Progress "Fetching $($Source) images from: $Uri"
        $response = try {
            Invoke-WebRequest -Uri $Uri -Headers $headers -UseBasicParsing
        } catch {
            $_.Exception.Response
        }

        if ($response.StatusCode -eq 304) {
            Write-Verbose "No updates found. Extending cache validity."
            $cache.lastUpdate = $currentTime
            $cache | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFile -Force
            return $cache.builtins
        }

        if (-not $response.Content) {
            throw [WslManagerException]::new("The response content from $Uri is null. Please check the URL or network connection.")
        }
        $etag = $response.Headers["ETag"]

        $distributionsObjects =  $response.Content | ConvertFrom-Json
        $distributions = $distributionsObjects | ForEach-Object { [WslImage]::new($_) }

        $cacheData = @{
            URl        = $Uri
            lastUpdate = $currentTime
            etag       = $etag
            builtins   = $distributions
        }
        $WslImageCacheFileCache[$Source] = $cacheData

        $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFile -Force
        return $distributions

    } catch {
        if ($_.Exception -is [WslManagerException]) {
            throw $_.Exception
        }
        Write-Error "Failed to retrieve builtin root filesystems: $($_.Exception.Message)"
        return $null
    }
}
