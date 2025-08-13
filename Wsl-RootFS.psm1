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

using namespace System.IO;

. "$PSScriptRoot\download.ps1"

# Cache the distributions data at script level
$script:Distributions = Import-PowerShellDataFile "$PSScriptRoot\Distributions.psd1"

enum WslRootFileSystemState {
    NotDownloaded
    Synced
    Outdated
}

enum WslRootFileSystemType {
    Builtin
    Incus
    Local
    Uri
}

. "$PSScriptRoot\Wsl-RootFS\Wsl-RootFS.Helpers.ps1"
. "$PSScriptRoot\Wsl-RootFS\Wsl-RootFS.Types.ps1"
. "$PSScriptRoot\Wsl-RootFS\Wsl-RootFS.Cmdlets.ps1"
. "$PSScriptRoot\Wsl-RootFS\Wsl-RootFS.Docker.ps1"

Export-ModuleMember New-WslRootFileSystem
Export-ModuleMember Sync-File
Export-ModuleMember Sync-WslRootFileSystem
Export-ModuleMember Get-WslRootFileSystem
Export-ModuleMember Remove-WslRootFileSystem
Export-ModuleMember Get-IncusRootFileSystem
Export-ModuleMember New-WslRootFileSystemHash
Export-ModuleMember Get-DockerImageLayer
Export-ModuleMember Get-DockerImageLayerManifest
Export-ModuleMember Get-DockerAuthToken
Export-ModuleMember Progress
Export-ModuleMember Success
Export-ModuleMember Information

# Define the types to export with type accelerators.
# Note: Unlike the `using module` approach, this approach allows
#       you to *selectively* export `class`es and `enum`s.
$exportableTypes = @(
  [WslRootFileSystem]
)

# Get the non-public TypeAccelerators class for defining new accelerators.
$typeAcceleratorsClass = [PSObject].Assembly.GetType('System.Management.Automation.TypeAccelerators')

# Add type accelerators for every exportable type.
$existingTypeAccelerators = $typeAcceleratorsClass::Get
foreach ($type in $exportableTypes) {
  # !! $TypeAcceleratorsClass::Add() quietly ignores attempts to redefine existing
  # !! accelerators with different target types, so we check explicitly.
  $existing = $existingTypeAccelerators[$type.FullName]
  if ($null -ne $existing -and $existing -ne $type) {
    throw "Unable to register type accelerator [$($type.FullName)], because it is already defined with a different type ([$existing])."
  }
  $typeAcceleratorsClass::Add($type.FullName, $type)
}
