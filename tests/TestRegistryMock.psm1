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

class MockRegistryKey {
    # BEWARE! Name must be the key (Guid) of the registry key
    [string]$Name
    [string]$Key

    static [hashtable]$RegistryByName = @{}
    static [hashtable]$RegistryByKey = @{}
    static [string]$WslRoot = "$env:LOCALAPPDATA\Wsl"

    MockRegistryKey([string]$Name) {
        $this.Key = $Name
        if (-not [MockRegistryKey]::RegistryByName.ContainsKey($this.Key)) {
            $this.Name = [Guid]::NewGuid().ToString()
            $path = Join-Path ([MockRegistryKey]::WslRoot) $Name
            New-Item -Path $path -ItemType Directory -Force | Out-Null
            $Values= [hashtable]@{
                DistributionName = $this.Key
                DefaultUid = 0
                BasePath = "\\?\$path"
                Guid = $this.Name
            }
            [MockRegistryKey]::RegistryByName[$this.Key] = $Values
            [MockRegistryKey]::RegistryByKey[$this.Name] = $Values
        } else {
            $this.Name = [MockRegistryKey]::RegistryByName[$this.Key].Guid
        }
    }

    [object] GetValue([string]$Name) {
        $value = [MockRegistryKey]::RegistryByName[$this.Key][$Name]
        return $value
    }

    [object] GetValue([string]$Name, [object]$defaultValue) {
        $entry = [MockRegistryKey]::RegistryByName[$this.Key]
        if (-not $entry.ContainsKey($Name)) {
            return $defaultValue
        }
        $value = $entry[$Name]
        return $value
    }

    [void] SetValue([string]$Name, [object]$Value) {
        [MockRegistryKey]::RegistryByName[$this.Key][$Name] = $Value
    }

    [void] Close() {
    }

    static [void]ClearAll() {
        [MockRegistryKey]::RegistryByKey.Clear()
        [MockRegistryKey]::RegistryByName.Clear()
    }
}

class MockBaseKey {
    [hashtable]$Values = @{}

    static [MockBaseKey]$Instance = [MockBaseKey]::new()

    MockBaseKey() {
        # Create some default distributions.  cspell:disable-next-line
        $instances = @("base", "goarch", "alpine322", "alpine321") | ForEach-Object { return [MockRegistryKey]::new($_) }
        $Default = $instances[0].Name
        $this.Values['DefaultDistribution'] = $Default
    }

    [string[]]GetSubKeyNames() {
        $GuidArray = [MockRegistryKey]::RegistryByKey.Keys
        return $GuidArray
    }

    [object] OpenSubKey([string]$Name, [bool]$Writable) {
        return [MockRegistryKey]::new([MockRegistryKey]::RegistryByKey[$Name].DistributionName)
    }

    [void] SetValue([string]$Name, [object]$Value) {
        $this.Values[$Name] = $Value
    }

    [object] GetValue([string]$Name) {
        return $this.Values[$Name]
    }

    [object] GetValue([string]$Name, [object]$defaultValue) {
        if (-not $this.Values.ContainsKey($Name)) {
            return $defaultValue
        }
        $value = $this.Values[$Name]
        return $value
    }

    [void] Close() {
    }

    static [void]Reset() {
        [MockRegistryKey]::ClearAll()
        [MockBaseKey]::Instance = [MockBaseKey]::new()
    }
}


$exportableTypes = @(
  [MockRegistryKey]
  [MockBaseKey]
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
