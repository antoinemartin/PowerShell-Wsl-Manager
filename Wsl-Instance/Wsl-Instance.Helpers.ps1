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

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseApprovedVerbs', '', Scope = 'Function', Target = "Wrap-*")]
Param()

if ($PSVersionTable.PSVersion.Major -lt 6) {
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidAssignmentToAutomaticVariable', $null, Scope = 'Function')]
    $IsWindows = $true
}

if ($IsWindows) {
    $wslPath = "$env:windir\system32\wsl.exe"
    if (-not [System.Environment]::Is64BitProcess) {
        # Allow launching WSL from 32 bit powershell
        $wslPath = "$env:windir\sysnative\wsl.exe"
    }

}
else {
    # If running inside WSL, rely on wsl.exe being in the path.
    $wslPath = "wsl.exe"
}


# Helper that will launch wsl.exe, correctly parsing its output encoding, and throwing an error
# if it fails.
function Wrap-Wsl {
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )

    $hasError = $false
    try {
        $oldOutputEncoding = [System.Console]::OutputEncoding
        [System.Console]::OutputEncoding = [System.Text.Encoding]::Unicode
        Write-Verbose "Piping wsl.exe with arguments: $($Arguments -join ' ')"
        $output = &$wslPath @Arguments
        if ($LASTEXITCODE -ne 0) {
            throw [WslManagerException]::new("wsl.exe failed: $output")
            $hasError = $true
        }

    }
    finally {
        [System.Console]::OutputEncoding = $oldOutputEncoding
    }

    # $hasError is used so there's no output in case error action is silently continue.
    if (-not $hasError) {
        return $output
    }
}

function Wrap-Wsl-Raw {
    param(
        [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
        [string[]]$Arguments
    )
    Write-Verbose "Running wsl.exe with arguments: $($Arguments -join ' ')"
    &$wslPath $Arguments
}


# WSL Registry Key class that uses reg.exe to access Windows registry from WSL
class WslRegistryKey {
    [string]$KeyPath
    [string]$Name

    WslRegistryKey([string]$KeyPath) {
        $this.KeyPath = $KeyPath
        # Extract the GUID from the key path
        $this.Name = $KeyPath -replace '^.*\\([^\\]*)$', '$1'
    }

    [object] GetValue([string]$Name) {
        return $this.GetValue($Name, $null)
    }

    [object] GetValue([string]$Name, [object]$defaultValue) {
        try {
            # Use reg.exe to query the value
            $output = reg.exe query "$($this.KeyPath)" /v "$Name" 2>&1
            if ($LASTEXITCODE -ne 0) {
                return $defaultValue
            }

            # Parse the output: name    type    value
            $lines = @($output | Where-Object { $_ -match "^\s+$Name\s+" })
            if (-not $lines) {
                return $defaultValue
            }

            $line = $lines[0]
            # Extract value from the line (format: "    Name    REG_TYPE    Value")
            if ($line -match "^\s+$Name\s+REG_\w+\s+(.*)$") {
                $value = $matches[1].Trim()

                # Handle different types
                if ($line -match 'REG_DWORD') {
                    return [int]"0x$value"
                }
                return $value
            }

            return $defaultValue
        } catch {
            Write-Verbose "Failed to get registry value $Name from $($this.KeyPath): $_"
            return $defaultValue
        }
    }

    [void] SetValue([string]$Name, [object]$Value) {
        try {
            # Determine registry type based on value type
            $regType = 'REG_SZ'
            $regValue = $Value

            if ($Value -is [int]) {
                $regType = 'REG_DWORD'
                $regValue = $Value.ToString()
            } elseif ($Value -is [string]) {
                $regType = 'REG_SZ'
                $regValue = $Value
            }

            # Use reg.exe to set the value
            $output = reg.exe add "$($this.KeyPath)" /v "$Name" /t $regType /d "$regValue" /f 2>&1
            if ($LASTEXITCODE -ne 0) {
                throw [WslManagerException]::new("Failed to set registry value: $output")
            }
        } catch {
            throw [WslManagerException]::new("Failed to set registry value $Name in $($this.KeyPath): $_")
        }
    }

    [void] Close() {
        # No-op for reg.exe based implementation
    }
}

# This one is here in order to perform unit test mocking
function Get-WslRegistryBaseKey() {
    return [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([WslInstance]::BaseInstancesRegistryPath, $true)
}

function Get-WslRegistryKey([string]$DistroName) {
    # If running in WSL, use reg.exe to access Windows registry
    if (-not $IsWindows) {
        try {
            $baseKeyPath = "HKCU\$([WslInstance]::BaseInstancesRegistryPath)"

            # Get all sub keys
            $output = reg.exe query "$baseKeyPath" 2>&1
            if ($LASTEXITCODE -ne 0) {
                Write-Verbose "Failed to query registry: $output"
                return $null
            }

            # Find sub keys (lines that start with HKEY)
            $subKeys = @($output | Where-Object { $_ -match "^HKEY" })

            foreach ($subKeyPath in $subKeys) {
                # Query the DistributionName value
                $distroOutput = reg.exe query "$subKeyPath" /v DistributionName 2>&1
                if ($LASTEXITCODE -eq 0) {
                    # Parse the distribution name
                    $nameLine = $distroOutput | Where-Object { $_ -match "^\s+DistributionName\s+" }
                    if ($nameLine -and $nameLine -match "^\s+DistributionName\s+REG_\w+\s+(.*)$") {
                        $distroNameValue = $matches[1].Trim()
                        if ($distroNameValue -eq $DistroName) {
                            return [WslRegistryKey]::new($subKeyPath)
                        }
                    }
                }
            }

            return $null
        } catch {
            Write-Verbose "Failed to query WSL registry: $_"
            return $null
        }
    }

    # Windows implementation
    $baseKey =  $null
    try {
        $baseKey = [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([WslInstance]::BaseInstancesRegistryPath, $true)
        return $baseKey.GetSubKeyNames() |
            Where-Object {
                $subKey = $baseKey.OpenSubKey($_, $false)
                try {
                    $subKey.GetValue('DistributionName') -eq $DistroName
                } finally {
                    if ($null -ne $subKey) {
                        $subKey.Close()
                    }
                }
            } | ForEach-Object {
                return $baseKey.OpenSubKey($_, $true)
            }
    } finally {
        if ($null -ne $baseKey) {
            $baseKey.Close()
        }
    }
}


# Helper to parse the output of wsl.exe --list
function Get-WslHelper() {
    Wrap-Wsl --list --verbose | Select-Object -Skip 1 | ForEach-Object {
        $fields = $_.Split(@(" "), [System.StringSplitOptions]::RemoveEmptyEntries)
        $defaultDistro = $false
        if ($fields.Count -eq 4) {
            $defaultDistro = $true
            $fields = $fields | Select-Object -Skip 1
        }

        [WslInstance]@{
            Name    = $fields[0]
            State   = $fields[1]
            Version = [int]$fields[2]
            Default = $defaultDistro
        }
    }
}
