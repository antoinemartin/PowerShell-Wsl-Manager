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

$WslRootFileSystemSources = @{
    [WslRootFileSystemSource]::Incus = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json"
    [WslRootFileSystemSource]::Builtins = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json"
}

$WslRootFileSystemCacheFileCache = @{}

function Get-WslBuiltinRootFileSystem {
    <#
    .SYNOPSIS
    Gets the list of builtin WSL root filesystems from the remote repository.

    .DESCRIPTION
    The Get-WslBuiltinRootFileSystem cmdlet fetches the list of available builtin
    WSL root filesystems from the official PowerShell-Wsl-Manager repository.
    This provides an up-to-date list of supported distributions that can be used
    to create WSL distributions.

    The cmdlet downloads a JSON file from the remote repository and converts it
    into WslRootFileSystem objects that can be used with other Wsl-Manager commands.
    The cmdlet implements intelligent caching with ETag support to reduce network
    requests and improve performance. Cached data is valid for 24 hours unless the
    -Sync parameter is used to force a refresh.

    .PARAMETER Source
    Specifies the source type for fetching root filesystems. Must be of type
    WslRootFileSystemSource. Defaults to [WslRootFileSystemSource]::Builtins
    which points to the official repository of builtin distributions.

    .PARAMETER Sync
    Forces a synchronization with the remote repository, bypassing the local cache.
    When specified, the cmdlet will always fetch the latest data from the remote
    repository regardless of cache validity period and ETag headers.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem

    Gets all available builtin root filesystems from the default repository source.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem -Source Builtins

    Explicitly gets builtin root filesystems from the builtins source.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem -Sync

    Forces a fresh download of all builtin root filesystems, ignoring local cache
    and ETag headers.

    .INPUTS
    None. You cannot pipe objects to Get-WslBuiltinRootFileSystem.

    .OUTPUTS
    WslRootFileSystem[]
    Returns an array of WslRootFileSystem objects representing the available
    builtin distributions.

    .NOTES
    - This cmdlet requires an internet connection to fetch data from the remote repository
    - The source URL is determined by the WslRootFileSystemSources hashtable using the Source parameter
    - Returns null if the request fails or if no distributions are found
    - The Progress function is used to display download status during network operations
    - Uses HTTP ETag headers for efficient caching and conditional requests (304 responses)
    - Cache is stored in the WslRootFileSystem base path with filename from the URI
    - Cache validity period is 24 hours (86400 seconds)
    - In-memory cache (WslRootFileSystemCacheFileCache) is used alongside file-based cache
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
        [WslRootFileSystemSource]$Source = [WslRootFileSystemSource]::Builtins,
        [switch]$Sync
    )

    $Uri = [System.Uri]$WslRootFileSystemSources[$Source]
    $CacheFilename = $Uri.Segments[-1]
    $cacheFile = Join-Path -Path ([WslRootFileSystem]::BasePath) -ChildPath $CacheFilename
    $currentTime = [int][double]::Parse((Get-Date -UFormat %s))
    $cacheValidDuration = 86400 # 24 hours in seconds

    $hasCacheFile = $WslRootFileSystemCacheFileCache.ContainsKey($Source) -or (Test-Path $cacheFile)
    # Populate cache if not already done
    if ($hasCacheFile -and -not $WslRootFileSystemCacheFileCache.ContainsKey($Source)) {
        $cache = Get-Content -Path $cacheFile | ConvertFrom-Json
        $WslRootFileSystemCacheFileCache[$Source] = $cache
        $cache.builtins = $cache.builtins | ForEach-Object {
            [WslRootFileSystem]::new($_)
        }
    }

    if (-not $Sync -and $hasCacheFile) {
        $cache = $WslRootFileSystemCacheFileCache[$Source]
        Write-Verbose "Cache lastUpdate: $($cache.lastUpdate) Current time $($currentTime), diff $($currentTime - $cache.lastUpdate)"
        if (($currentTime - $cache.lastUpdate) -lt $cacheValidDuration -and $null -ne $cache.builtins) {
            return $cache.builtins
        }
    }

    try {
        $headers = @{}
        if ($hasCacheFile) {
            $cache = $WslRootFileSystemCacheFileCache[$Source]
            if ($cache.etag) {
                $headers = @{ "If-None-Match" = $cache.etag[0] }
            }
        }


        Progress "Fetching builtin distributions from: $Uri"
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
            throw "The response content is null. Please check the URL or network connection."
        }
        $etag = $response.Headers["ETag"]

        $distributions = $response.Content | ConvertFrom-Json | ForEach-Object { [WslRootFileSystem]::new($_) }

        $cacheData = @{
            URl        = $Uri
            lastUpdate = $currentTime
            etag       = $etag
            builtins   = $distributions
        }
        $WslRootFileSystemCacheFileCache[$Source] = $cacheData

        $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFile -Force
        return $distributions

    } catch {
        Write-Error "Failed to retrieve builtin root filesystems: $($_.Exception.Message)"
        return $null
    }
}
