[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
Param(
    [switch]$All,
    [string]$Format = 'CoverageGutters'
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

    # $PesterConfiguration.Filter.FullName                   = "WslImage.*"
    # $PesterConfiguration.Filter.FullName                  = "WslImage.Docker.Should fail gracefully when auth token cannot be retrieved"
    # $PesterConfiguration.Filter.FullName                   = "WslInstance.*"
    # $PesterConfiguration.Filter.FullName                   = "WslImage.Should check single hash"
    # $PesterConfiguration.Filter.FullName                   = "WslInstance.should create instance"
    $PesterConfiguration.Filter.FullName                   = "SQLite.Named Parameters.*"
    # $PesterConfiguration.Filter.FullName                   = "WslImage.Database.*"
}
Invoke-Pester -Configuration $PesterConfiguration
