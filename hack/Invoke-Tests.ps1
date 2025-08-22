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
# $PesterConfiguration.Filter.FullName                      = "WslImage.Should convert PSObject with nested table to hashtable"
# $PesterConfiguration.Filter.FullName                      = "WslInstance.should create distribution"
Invoke-Pester -Configuration $PesterConfiguration
