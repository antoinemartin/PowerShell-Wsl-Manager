[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
Param(
    [switch]$All
)

Import-Module -Name 'Pester' -ErrorAction Stop
$PesterConfiguration                                      = [PesterConfiguration]::new()
$PesterConfiguration.TestResult.Enabled                   = $true
$PesterConfiguration.TestResult.OutputFormat              = 'JUnitXml'
# $PesterConfiguration.CodeCoverage.OutputFormat            = 'Cobertura'
$PesterConfiguration.CodeCoverage.OutputFormat            = 'CoverageGutters'
$PesterConfiguration.CodeCoverage.CoveragePercentTarget   = 10
$PesterConfiguration.CodeCoverage.Path                    = @("Wsl-Manager.psm1", "Wsl-Image", "Wsl-Instance")
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
    $PesterConfiguration.Filter.FullName                  = "WslImage.Docker.Should fail gracefully when auth token cannot be retrieved"
    # $PesterConfiguration.Filter.FullName                   = "WslInstance.*"
    # $PesterConfiguration.Filter.FullName                   = "WslImage.Should download checksum hashes"
    # $PesterConfiguration.Filter.FullName                   = "WslInstance.should create distribution"
}
Invoke-Pester -Configuration $PesterConfiguration
