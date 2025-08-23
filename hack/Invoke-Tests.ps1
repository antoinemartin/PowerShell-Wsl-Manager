[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidGlobalVars', '')]
Param()

Import-Module -Name 'Pester' -ErrorAction Stop
$PesterConfiguration                                      = [PesterConfiguration]::new()
$PesterConfiguration.TestResult.Enabled                   = $true
$PesterConfiguration.TestResult.OutputFormat              = 'JUnitXml'
$PesterConfiguration.CodeCoverage.Enabled                 = $true
# $PesterConfiguration.CodeCoverage.OutputFormat            = 'Cobertura'
$PesterConfiguration.CodeCoverage.OutputFormat            = 'CoverageGutters'
$PesterConfiguration.CodeCoverage.CoveragePercentTarget   = 10
$PesterConfiguration.CodeCoverage.Path                    = @("Wsl-Manager.psm1", "Wsl-Common", "Wsl-Image", "Wsl-Instance")
$PesterConfiguration.Output.Verbosity                     = 'Normal'
# $PesterConfiguration.Output.Verbosity                     = 'Detailed'
$PesterConfiguration.Output.CIFormat                      = 'GithubActions'
$PesterConfiguration.Run.PassThru                         = $false
# $PesterConfiguration.Filter.FullName                      = "WslImage.*"
# $PesterConfiguration.Filter.FullName                      = "WslImage.Docker.*"
# $PesterConfiguration.Filter.FullName                      = "WslInstance.*"
# $PesterConfiguration.Filter.FullName                      = "WslImage.Should match file name to builtin"
# $PesterConfiguration.Filter.FullName                      = "WslInstance.should create distribution"
$Global:PesterShowMock = $false
Invoke-Pester -Configuration $PesterConfiguration
