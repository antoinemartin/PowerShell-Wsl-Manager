[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
Param(
    [Parameter(Mandatory = $false)]
    [switch]$All,
    [Parameter(Mandatory = $false)]
    [string]$Format = 'CoverageGutters',
    [Parameter(Mandatory = $false)]
    [string]$Filter = $null
)

$coverageFiles = Import-PowerShellDataFile .\Wsl-Manager.psd1 | Select-Object -Property RootModule,NestedModules | ForEach-Object { @($_.RootModule) + $_.NestedModules } | Where-Object { $_ -notlike "*.Helpers.ps1" }

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
    } else {
        Write-Host "No filter specified, running all tests in Wsl-Image.*"
        $PesterConfiguration.Filter.FullName                   = "WslImage.*"
    }
}
Invoke-Pester -Configuration $PesterConfiguration
