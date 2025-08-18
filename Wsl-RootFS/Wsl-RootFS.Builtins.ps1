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
    The cmdlet implements caching to reduce network requests and improve performance.
    Cached data is valid for 24 hours unless the -Sync parameter is used.

    .PARAMETER Name
    Optional parameter to filter the results by distribution name. Supports wildcards.
    Default value is "*" which returns all available distributions.

    .PARAMETER Url
    The URL to fetch the distributions JSON data from. Defaults to the official
    PowerShell-Wsl-Manager repository URL. This parameter allows for custom
    distribution sources if needed.

    .PARAMETER Sync
    Forces a synchronization with the remote repository, bypassing the local cache.
    When specified, the cmdlet will always fetch the latest data from the remote
    repository regardless of cache validity period.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem

    Gets all available builtin root filesystems from the default repository.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem -Name "Ubuntu*"

    Gets all Ubuntu-related builtin root filesystems using wildcard matching.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem -Name "Arch"

    Gets the specific Arch Linux builtin root filesystem.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem -Url "https://custom.repo/distributions.json"

    Gets builtin root filesystems from a custom repository URL.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem -Sync

    Forces a fresh download of all builtin root filesystems, ignoring local cache.

    .INPUTS
    None. You cannot pipe objects to Get-WslBuiltinRootFileSystem.

    .OUTPUTS
    WslRootFileSystem[]
    Returns an array of WslRootFileSystem objects representing the available
    builtin distributions.

    .NOTES
    - This cmdlet requires an internet connection to fetch data from the remote repository
    - The default URL points to: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/main/docs/assets/distributions.json
    - Returns null if the request fails or if no distributions are found
    - The Progress function is used to display download status
    - Uses HTTP ETag headers for efficient caching and conditional requests
    - Cache is stored in the WslRootFileSystem base path as "builtins.json"
    - Cache validity period is 24 hours (86400 seconds)

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
        [string]$Name = "*",
        [Parameter(Mandatory = $false)]
        [string]$Url = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json",
        [switch]$Sync
    )

    $cacheFile = Join-Path -Path ([WslRootFileSystem]::BasePath) -ChildPath "builtins.json"
    $currentTime = [int][double]::Parse((Get-Date -UFormat %s))
    $cacheValidDuration = 86400 # 24 hours in seconds

    if (-not $Sync -and (Test-Path $cacheFile)) {
        $cache = Get-Content -Path $cacheFile | ConvertFrom-Json
        if (($currentTime - $cache.lastUpdate) -lt $cacheValidDuration -and $null -ne $cache.builtins) {
            return $cache.builtins | ForEach-Object { [WslRootFileSystem]::new($_) }
        }
    }

    try {
        $headers = @{}
        if (Test-Path $cacheFile) {
            $cache = Get-Content -Path $cacheFile | ConvertFrom-Json
            if ($cache.etag) {
                $headers = @{ "If-None-Match" = $cache.etag[0] }
            }
        }


        Progress "Fetching builtin distributions from: $Url"
        $response = try {
            Invoke-WebRequest -Uri $Url -Headers $headers -UseBasicParsing
        } catch {
            $_.Exception.Response
        }

        if ($response.StatusCode -eq 304) {
            Write-Verbose "No updates found. Extending cache validity."
            $cache.lastUpdate = $currentTime
            $cache | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFile -Force
            return $cache.builtins | ForEach-Object { [WslRootFileSystem]::new($_) }
        }

        if (-not $response.Content) {
            throw "The response content is null. Please check the URL or network connection."
        }
        $etag = $response.Headers["ETag"]

        $distributions = $response.Content | ConvertFrom-Json | ForEach-Object { [WslRootFileSystem]::new($_) }

        $cacheData = @{
            lastUpdate = $currentTime
            etag       = $etag
            builtins   = $distributions
        }

        $cacheData | ConvertTo-Json -Depth 10 | Set-Content -Path $cacheFile -Force
        return $distributions

    } catch {
        Write-Error "Failed to retrieve builtin root filesystems: $($_.Exception.Message)"
        return $null
    }
}
