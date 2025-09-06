#!/usr/bin/env pwsh
#Requires -Version 7.0

<#
.SYNOPSIS
    Builds the pre-compiled SQLite helper library for WSL Manager.

.DESCRIPTION
    This script compiles the SQLiteHelper class library for multiple target frameworks
    to avoid runtime compilation overhead when the PowerShell module loads.

.PARAMETER Configuration
    The build configuration (Debug or Release). Default is Release.

.PARAMETER Clean
    If specified, cleans the build output before building.

.PARAMETER VerboseBuild
    If specified, enables verbose output during build.

.EXAMPLE
    .\Build-SQLiteHelper.ps1
    Builds the library in Release configuration.

.EXAMPLE
    .\Build-SQLiteHelper.ps1 -Configuration Debug -Clean -VerboseBuild
    Cleans and builds the library in Debug configuration with verbose output.
#>

[CmdletBinding()]
param(
    [ValidateSet('Debug', 'Release')]
    [string]$Configuration = 'Release',

    [switch]$Clean,

    [switch]$VerboseBuild
)

Set-StrictMode -Version Latest
$ErrorActionPreference = 'Stop'

# Get the directory containing this script
$ScriptDir = $PSScriptRoot
$ProjectPath = Join-Path $ScriptDir 'WslSQLiteHelper.csproj'

# Ensure dotnet CLI is available
try {
    $dotnetVersion = dotnet --version
    Write-Host "Using .NET CLI version: $dotnetVersion" -ForegroundColor Green
} catch {
    throw "dotnet CLI is not available. Please install .NET SDK."
}

# Clean if requested
if ($Clean) {
    Write-Host "Cleaning build output..." -ForegroundColor Yellow
    dotnet clean $ProjectPath --configuration $Configuration --verbosity minimal
    if ($LASTEXITCODE -ne 0) {
        throw "Clean failed with exit code $LASTEXITCODE"
    }
}

# Build arguments
$buildArgs = @(
    'build'
    $ProjectPath
    '--configuration', $Configuration
    '--no-restore'
)

if ($VerboseBuild) {
    $buildArgs += '--verbosity', 'normal'
} else {
    $buildArgs += '--verbosity', 'minimal'
}

# Restore packages first
Write-Host "Restoring packages..." -ForegroundColor Yellow
dotnet restore $ProjectPath --verbosity minimal
if ($LASTEXITCODE -ne 0) {
    throw "Package restore failed with exit code $LASTEXITCODE"
}

# Build the project
Write-Host "Building SQLite Helper library..." -ForegroundColor Yellow
Write-Host "Command: dotnet $($buildArgs -join ' ')" -ForegroundColor Gray

& dotnet @buildArgs

if ($LASTEXITCODE -ne 0) {
    throw "Build failed with exit code $LASTEXITCODE"
}

# Show build output
$binPath = Join-Path $ScriptDir 'bin'
if (Test-Path $binPath) {
    Write-Host "`nBuild output:" -ForegroundColor Green
    Get-ChildItem $binPath -Recurse -File | ForEach-Object {
        $relativePath = $_.FullName.Substring($ScriptDir.Length + 1)
        Write-Host "  $relativePath" -ForegroundColor Gray
    }
} else {
    Write-Warning "Build output directory not found: $binPath"
}

Write-Host "`nBuild completed successfully!" -ForegroundColor Green
