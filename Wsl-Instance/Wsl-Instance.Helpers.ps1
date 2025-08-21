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
        $output = &$wslPath $Arguments
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

    &$wslPath $Arguments
}


# This one is here in order to perform unit test mocking
function Get-WslRegistryBaseKey() {
    return [Microsoft.Win32.Registry]::CurrentUser.OpenSubKey([WslInstance]::BaseInstancesRegistryPath, $true)
}

function Get-WslRegistryKey([string]$DistroName) {

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
