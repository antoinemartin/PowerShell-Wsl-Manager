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

    .PARAMETER Name
    Optional parameter to filter the results by distribution name. Supports wildcards.
    Default value is "*" which returns all available distributions.

    .PARAMETER Url
    The URL to fetch the distributions JSON data from. Defaults to the official
    PowerShell-Wsl-Manager repository URL. This parameter allows for custom
    distribution sources if needed.

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

    .INPUTS
    None. You cannot pipe objects to Get-WslBuiltinRootFileSystem.

    .OUTPUTS
    WslRootFileSystem[]
    Returns an array of WslRootFileSystem objects representing the available
    builtin distributions.

    .NOTES
    - This cmdlet requires an internet connection to fetch data from the remote repository
    - The default URL points to: https://mrtn.me/PowerShell-Wsl-Manager/assets/distributions.json
    - Returns null if the request fails or if no distributions are found
    - The Progress function is used to display download status

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
        [string]$Url = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/main/docs/assets/distributions.json"
    )

    try {
        # Fetch the JSON data from the remote URL
        Progress "Fetching builtin distributions from: $Url"

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
