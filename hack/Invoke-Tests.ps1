[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
Param(
    [Parameter(Mandatory = $false)]
    [switch]$All,
    [Parameter(Mandatory = $false)]
    [string]$Format = 'CoverageGutters',
    [Parameter(Mandatory = $false)]
    [string]$Filter = $null
)

<#
.SYNOPSIS
    Runs Pester tests with optional code coverage analysis.

.DESCRIPTION
    This script runs Pester tests for the Wsl-Manager module. When run with -All switch,
    it enables code coverage and post-processes the generated coverage.xml file to exclude
    lines marked with "# nocov" comments from coverage calculations.

    Supports two types of exclusions:
    1. Individual line exclusion: Place "# nocov" at the end of any line
    2. Block exclusion: Place "# nocov" on the same line as an opening brace { to exclude the entire block

.PARAMETER All
    Enables code coverage analysis and runs all tests.

.PARAMETER Format
    Specifies the code coverage output format. Default is 'CoverageGutters'.

.PARAMETER Filter
    Filters tests by name pattern when not running with -All switch.

.NOTES
    Lines in source files containing "# nocov" comments will be automatically excluded
    from code coverage calculations when running with -All switch.

    Examples:
    - Line exclusion: Write-Host "Debug info" # nocov
    - Block exclusion: if ($debug) { # nocov
                         Write-Host "Debug block"
                         $debugVar = $true
                       }
#>

$coverageFiles = Import-PowerShellDataFile .\Wsl-Manager.psd1 | Select-Object -Property RootModule,NestedModules | ForEach-Object { @($_.RootModule) + $_.NestedModules } | Where-Object { $_ -notlike "*.Helpers.ps1"  -or $_ -like "*Wsl-ImageSource.Helpers.ps1" }

Import-Module -Name 'Pester' -ErrorAction Stop
$PesterConfiguration                                      = [PesterConfiguration]::new()
$PesterConfiguration.TestResult.Enabled                   = $true
$PesterConfiguration.TestResult.OutputFormat              = 'JUnitXml'
# $PesterConfiguration.CodeCoverage.OutputFormat            = 'Cobertura'
$PesterConfiguration.CodeCoverage.OutputFormat            = $Format
$PesterConfiguration.CodeCoverage.CoveragePercentTarget   = 85
$PesterConfiguration.CodeCoverage.Path                    = $coverageFiles
$PesterConfiguration.CodeCoverage.UseBreakpoints          = $true
$PesterConfiguration.Output.CIFormat                      = 'GithubActions'
$PesterConfiguration.Run.PassThru                         = $false
if ($All) {
    $Global:PesterShowMock                                = $false
    $PesterConfiguration.CodeCoverage.Enabled             = $true
    $PesterConfiguration.Output.Verbosity                 = 'Normal'
} else {
    $Global:PesterShowMock = $true
    $PesterConfiguration.CodeCoverage.Enabled             = $false
    $PesterConfiguration.Output.Verbosity                 = 'Detailed'

    if ($Filter) {
        Write-Host "Filtering tests with: $Filter"
        $PesterConfiguration.Filter.FullName               = $Filter
    }
}

Invoke-Pester -Configuration $PesterConfiguration
Write-Host "Pester tests completed."

# Post-process coverage.xml to exclude lines with # nocov comments
if (($true -eq $PesterConfiguration.CodeCoverage.Enabled.Value) -and (Test-Path 'coverage.xml')) {
    Write-Host "Post-processing coverage.xml to exclude # nocov lines..."
    & "$PSScriptRoot/Update-CoverageXmlForNoCov.ps1" -CoverageFilePath 'coverage.xml'
}
