# cSpell: ignore winsqlite libsqlite dylib
# Load pre-compiled SQLite helper type [WslManager.SQLiteHelper] to avoid compilation overhead.
# This uses the pre-compiled assembly from the bin directory.
#
# Gracefully adapted from https://stackoverflow.com/a/76488520/45375
#
# For cross-platform compatibility, we build multiple target frameworks:
# - .NET 8.0+ for modern PowerShell Core
# - .NET Framework 4.8 for Windows PowerShell

# Function to determine the best assembly to load based on the current PowerShell version
function Get-BestSQLiteHelperAssembly {
    param(
        [string]$BasePath
    )

    $binPath = Join-Path $BasePath 'bin'
    # Determine target framework based on PowerShell version
    if ($PSVersionTable.PSVersion.Major -ge 7) {
        $targetFramework = 'net8.0'
        if ($IsWindows) {
            $targetFramework += '-windows'
        }
    }
    else {
        $targetFramework = 'net48'
    }

    $binPath = Join-Path $binPath $targetFramework
    $assemblyName = 'WslSQLiteHelper.dll'
    $assemblyPath = Join-Path $binPath $assemblyName

    if (Test-Path $assemblyPath) {
        return $assemblyPath
    }

    # If pre-compiled assembly doesn't exist, fall back to runtime compilation
    Write-Warning "Pre-compiled SQLite helper assembly not found at '$assemblyPath'. Falling back to runtime compilation."
    return $null
}

# Function to load pre-compiled assembly
function Import-PreCompiledSQLiteHelper {
    param(
        [string]$AssemblyPath
    )

    try {
        Add-Type -Path $AssemblyPath
        Write-Verbose "Successfully loaded pre-compiled SQLite helper from: $AssemblyPath"
        return $true
    }
    catch {
        Write-Warning "Failed to load pre-compiled SQLite helper: $($_.Exception.Message)"
        return $false
    }
}

# Function to compile SQLite helper at runtime (fallback)
function Import-RuntimeCompiledSQLiteHelper {
    param(
        [string]$BasePath
    )

    Write-Verbose "Compiling SQLite helper at runtime..."

    $TypeDefinition = Get-Content (Join-Path -Path $BasePath -ChildPath 'SQLiteHelper.cs') -Raw

    # Adjust library name based on platform
    if (-not ($IsLinux -or $IsMacOS)) {
        $CompilerOptions = "/define:WINDOWS"
    } else {
        $CompilerOptions = "/define:POSIX"
    }

    try {
        Add-Type -ReferencedAssemblies System.Collections, System.Data, System.Data.Common, System.Xml, System.ComponentModel.TypeConverter -Language CSharp -CompilerOptions $CompilerOptions -TypeDefinition $TypeDefinition
        Write-Verbose "Successfully compiled SQLite helper at runtime"
        return $true
    }
    catch {
        Write-Error "Failed to compile SQLite helper at runtime: $($_.Exception.Message)"
        return $false
    }
}

# Main loading logic
$assemblyPath = Get-BestSQLiteHelperAssembly -BasePath $PSScriptRoot

if ($assemblyPath -and (Import-PreCompiledSQLiteHelper -AssemblyPath $assemblyPath)) {
    # Pre-compiled assembly loaded successfully
    Write-Verbose "Using pre-compiled SQLite helper assembly"
}
elseif (Import-RuntimeCompiledSQLiteHelper -BasePath $PSScriptRoot) {
    # Runtime compilation succeeded
    Write-Verbose "Using runtime-compiled SQLite helper"
}
else {
    throw "Failed to load SQLite helper - both pre-compiled assembly and runtime compilation failed"
}

# Verify the type is available
try {
    # Runtime compiled version is in global namespace
    $null = [SQLiteHelper]
    Write-Verbose "SQLite helper type [SQLiteHelper] is available"
}
catch {
    throw "SQLite helper type is not available after loading: $($_.Exception.Message)"
}
