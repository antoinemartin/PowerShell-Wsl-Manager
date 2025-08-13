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

    The returned data structure is similar to the local Distributions.psd1 file
    but reflects the latest available distributions from the remote source.

    .PARAMETER Name
    Optional parameter to filter the results by distribution name. Supports wildcards.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem
    Gets all available builtin root filesystems.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem -Name "Ubuntu*"
    Gets all Ubuntu-related builtin root filesystems.

    .EXAMPLE
    Get-WslBuiltinRootFileSystem -Name "Arch"
    Gets the specific Arch builtin root filesystem.

    .NOTES
    This cmdlet requires an internet connection to fetch the latest data from
    https://mrtn.me/PowerShell-Wsl-Manager/assets/distributions.json
    #>
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false)]
        [string]$Name = "*"
    )

    try {
        # Fetch the JSON data from the remote URL
        $url = "https://mrtn.me/PowerShell-Wsl-Manager/assets/distributions.json"
        Progress "Fetching builtin distributions from: $url"

        $response = Invoke-RestMethod -Uri $url -UseBasicParsing -ErrorAction Stop

        # Convert the JSON response to a hashtable similar to Distributions.psd1 format
        $distributions = $response | ForEach-Object { [WslRootFileSystem]::new($_) }

        # Return the distributions hashtable
        return $distributions

    } catch {
        Write-Error "Failed to retrieve builtin root filesystems: $($_.Exception.Message)"
        return $null
    }
}
