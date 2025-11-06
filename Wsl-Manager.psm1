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

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingCmdletAliases', '',
    Justification = 'For compatibility with previous version')]
Param()


$tabCompletionScript = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    (Get-WslHelper).Name | Where-Object { $_ -ilike "$wordToComplete*" } | Sort-Object
}

$tabImageCompletionScript = {
    param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
    (Get-WslImage).Name | Where-Object { $_ -ilike "$wordToComplete*" } | Sort-Object
}


Register-ArgumentCompleter -CommandName Get-WslInstance,Remove-WslInstance,Export-WslInstance -ParameterName Name -ScriptBlock $tabCompletionScript
Register-ArgumentCompleter -CommandName Invoke-WslInstance -ParameterName 'In' -ScriptBlock $tabCompletionScript
Register-ArgumentCompleter -CommandName New-WslInstance -ParameterName 'From' -ScriptBlock $tabImageCompletionScript
Register-ArgumentCompleter -CommandName Stop-WslInstance -ParameterName 'Name' -ScriptBlock $tabCompletionScript

# Define the types to export with type accelerators.
# Note: Unlike the `using module` approach, this approach allows
#       you to *selectively* export `class`es and `enum`s.
$exportableTypes = @(
  [WslInstance]
  [WslImage]
  [WslImageSource]
  [WslImageDatabase]
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
    throw [WslManagerException]::new("Unable to register type accelerator [$($type.FullName)], because it is already defined with a different type ([$existing]).")
  }
  Write-Verbose "Exporting type accelerator [$($type.FullName)]"
  $typeAcceleratorsClass::Add($type.FullName, $type)
}


Set-Alias -Name Get-Wsl -Value Get-WslInstance -Force
Set-Alias -Name New-Wsl -Value New-WslInstance -Force
Set-Alias -Name Remove-Wsl -Value Remove-WslInstance -Force
Set-Alias -Name Stop-Wsl -Value Stop-WslInstance -Force
Set-Alias -Name Invoke-Wsl -Value Invoke-WslInstance -Force
Set-Alias -Name Export-Wsl -Value Export-WslInstance -Force
Set-Alias -Name Rename-Wsl -Value Rename-WslInstance -Force

# cSpell: disable
Set-Alias -Name gwsl -Value Get-WslInstance -Force
Set-Alias -Name nwsl -Value New-WslInstance -Force
Set-Alias -Name rmwsl -Value Remove-WslInstance -Force
Set-Alias -Name swsl -Value Stop-WslInstance -Force
Set-Alias -Name iwsl -Value Invoke-WslInstance -Force
Set-Alias -Name ewsl -Value Export-WslInstance -Force
Set-Alias -Name mvwsl -Value Rename-WslInstance -Force
Set-Alias -Name dwsl -Value Set-WslDefaultInstance -Force
Set-Alias -Name cwsl -Value Invoke-WslConfigure -Force

Set-Alias -Name gwsli -Value Get-WslImage -Force
Set-Alias -Name nwsli -Value New-WslImage -Force
Set-Alias -Name rmwsli -Value Remove-WslImage -Force
Set-Alias -Name swsli -Value Sync-WslImage -Force

Set-Alias -Name gwsls -Value Get-WslImageSource -Force

# cSpell: enable
