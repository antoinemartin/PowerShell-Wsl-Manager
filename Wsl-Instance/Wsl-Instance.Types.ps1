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

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]

$InstanceDatadir = if ($env:LOCALAPPDATA) { $env:LOCALAPPDATA } else { Join-Path -Path "$HOME" -ChildPath ".local/share" }
$base_wsl_directory = [DirectoryInfo]::new((Join-Path -Path $InstanceDatadir -ChildPath "Wsl"))
$ModuleDirectory = ([FileInfo]$MyInvocation.MyCommand.Path).Directory

function Get-ModuleDirectory() {
    return $ModuleDirectory
}

function Test-WslPath() {
    return $null -ne (Get-Command wslpath -ErrorAction SilentlyContinue)
}

function ConvertTo-WslPath([string]$Path) {  # nocov
    return wslpath $Path
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
            # On WSL where wslpath is available, convert the path if it's not already in Linux format
            if (-not (Test-WslPath) -or $path.StartsWith("\\?\/")) {
                if ($path.StartsWith("\\?\")) {
                    $path = $path.Substring(4)
                }
            } else {
                $path = ConvertTo-WslPath $path
            }

            $this.BasePath = [DirectoryInfo]::new($path)
            $this.DefaultUid = $key.GetValue('DefaultUid', 0)
            $this.ImageGuid = [Guid]::Parse($key.GetValue('WslPwshMgrImageGuid', [Guid]::Empty.ToString()))
            $this.ImageDigest = $key.GetValue('WslPwshMgrImageDigest', $null)
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

    [void]SetImageGuid([Guid]$ImageGuid) {
        $this.GetRegistryKey().SetValue('WslPwshMgrImageGuid', $ImageGuid.ToString())
        $this.ImageGuid = $ImageGuid
    }

    [void]SetImageDigest([string]$ImageDigest) {
        $this.GetRegistryKey().SetValue('WslPwshMgrImageDigest', $ImageDigest)
        $this.ImageDigest = $ImageDigest
    }

    [void]Configure([bool]$force = $false, [int]$Uid = 1000) {
        if (-not $force -and $this.Configured) {
            throw [WslManagerException]::new("Instance [$($this.Name)] is already configured, use -Force to reconfigure it.")
        }
        if ($force) {
            Write-Verbose "Force reconfiguration of instance [$($this.Name)]"
            Wrap-Wsl-Raw -Arguments '-d',$this.Name,'-u','root','rm','-rf','/etc/wsl-configured' 2>&1
        }
        $directory = (Get-ModuleDirectory).Parent.FullName
        Progress "Running initialization script [$($directory)/configure.sh] on instance [$($this.Name)]..."
        Push-Location $directory
        $output = Wrap-Wsl-Raw -Arguments '-d',$this.Name,'-u','root','./configure.sh' 2>&1
        Write-Verbose "Output: `n$($output -join "`n")`n<end of output>"
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
    [Guid]$ImageGuid
    [string]$ImageDigest
    [int]$DefaultUid = 0
    [FileSystemInfo]$BasePath

    static [DirectoryInfo]$DistrosRoot = $base_wsl_directory
    static [string]$BaseInstancesRegistryPath = "SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss"
}
