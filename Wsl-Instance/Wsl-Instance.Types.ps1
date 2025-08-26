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

$base_wsl_directory = [DirectoryInfo]::new("$env:LOCALAPPDATA\Wsl")
$ModuleDirectory = ([FileInfo]$MyInvocation.MyCommand.Path).Directory

function Get-ModuleDirectory() {
    return $ModuleDirectory
}

enum WslInstanceState {
    Stopped
    Running
    Installing
    Uninstalling
    Converting
}


# Represents a WSL instance.
class WslInstance {
    WslInstance() {
    }

    WslInstance([string]$Name) {
        $this.Name = $Name
        $path = Join-Path -Path ([WslInstance]::DistrosRoot).FullName -ChildPath $Name
        $this.BasePath = [DirectoryInfo]::new($path)
        $this.RetrieveProperties()
    }

    [string] ToString() {
        return $this.Name
    }

    [string] Unregister() {
        return Wrap-Wsl --unregister $this.Name
    }

    [void] Stop() {
        $null = Wrap-Wsl --terminate $this.Name
        $this.State = [WslInstanceState]::Stopped
        Write-Information "WSL instance [$this] stopped."
    }

    [object]GetRegistryKey() {
        return Get-WslRegistryKey $this.Name
    }

    [void]RetrieveProperties() {
        $key = $this.GetRegistryKey()
        if ($key) {
            $this.Guid = $key.Name -replace '^.*\\([^\\]*)$', '$1'
            $path = $key.GetValue('BasePath')
            if ($path.StartsWith("\\?\")) {
                $path = $path.Substring(4)
            }

            $this.BasePath = Get-Item -Path $path
            $this.DefaultUid = $key.GetValue('DefaultUid', 0)
        }
    }

    [void]Rename([string]$NewName) {

        $existing =  try {
            Get-WslInstance $NewName -ErrorAction SilentlyContinue
        } catch {
            $null
        }

        if ($null -ne $existing) {
            throw [WslInstanceAlreadyExistsException]$NewName
        }
        $this.GetRegistryKey().SetValue('DistributionName', $NewName)
        $this.Name = $NewName
        Success "Instance renamed to $NewName"
    }

    [void]SetDefaultUid([int]$Uid) {
        $this.GetRegistryKey().SetValue('DefaultUid', $Uid)
        $this.DefaultUid = $Uid
    }

    [void]Configure([bool]$force = $false, [int]$Uid = 1000) {
        if (-not $force -and $this.Configured) {
            throw [WslManagerException]::new("Instance [$($this.Name)] is already configured, use -Force to reconfigure it.")
        }
        $directory = (Get-ModuleDirectory).Parent.FullName
        Progress "Running initialization script [$($directory)/configure.sh] on instance [$($this.Name)]..."
        Push-Location $directory
        $output = Wrap-Wsl-Raw -Arguments '-d',$this.Name,'-u','root','./configure.sh' 2>&1
        Pop-Location
        if ($LASTEXITCODE -ne 0) {
            throw [WslManagerException]::new("Configuration failed: $output")
        }
        $this.SetDefaultUid(1000)
        Success "Configuration of instance [$($this.Name)] completed successfully."
    }

    [ValidateNotNullOrEmpty()][string]$Name
    [WslInstanceState]$State = [WslInstanceState]::Stopped
    [int]$Version = 2
    [bool]$Default = $false
    [Guid]$Guid
    [int]$DefaultUid = 0
    [FileSystemInfo]$BasePath
    [bool]$Configured = $false

    static [DirectoryInfo]$DistrosRoot = $base_wsl_directory
    static [string]$BaseInstancesRegistryPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss"
}
