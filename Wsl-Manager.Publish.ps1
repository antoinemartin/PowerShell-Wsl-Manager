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

$module = Test-ModuleManifest .\*.psd1
$moduleName = $module.Name
# $moduleVersion = $module.Version.ToString()
$modulePath = "$Env:TEMP\$(New-Guid)\$moduleName"

# [version]::new($moduleVersion).CompareTo([version]::new((Find-PSResource $moduleName).Version)) | Should -Be 1

New-Item $modulePath -ItemType Directory -Force | Out-Null
Copy-Item .\* $modulePath -Recurse -Exclude .github, *.Publish.ps1, *.Tests.ps1, .git
# Get-ChildItem $modulePath -Force | Select-Object -ExpandProperty Name | Should -BeExactly ".p10k.zsh", "configure.sh", "LICENSE", "README.md", "Wsl-Manager.psd1", "Wsl-Manager.psm1"

Publish-Module -Path "$modulePath" -NuGetApiKey "$($args[0])" -Verbose

Remove-Item $modulePath -Recurse -Force -ErrorAction Ignore
