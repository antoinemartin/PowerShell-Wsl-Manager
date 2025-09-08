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

# Post-process coverage.xml to exclude lines with # nocov comments
if ($PesterConfiguration.CodeCoverage.Enabled -and (Test-Path 'coverage.xml')) {
    Write-Host "Post-processing coverage.xml to exclude # nocov lines..."

    function Update-CoverageXmlForNoCov {
        [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
        param([string]$CoverageFilePath)

        # Load the XML
        [xml]$coverageXml = Get-Content $CoverageFilePath

        # Find all sourcefile elements
        $sourceFiles = $coverageXml.SelectNodes("//sourcefile")

        foreach ($sourceFile in $sourceFiles) {
            $sourceFileName = $sourceFile.GetAttribute("name")
            $sourceFilePath = $sourceFileName

            # Handle relative paths - look for the file in current directory and subdirectories
            if (-not (Test-Path $sourceFilePath)) {
                $possiblePaths = @(
                    ".\$sourceFileName",
                    ".\Wsl-Image\$sourceFileName",
                    ".\Wsl-Instance\$sourceFileName",
                    ".\Wsl-Common\$sourceFileName",
                    ".\Wsl-SQLite\$sourceFileName"
                )

                foreach ($path in $possiblePaths) {
                    if (Test-Path $path) {
                        $sourceFilePath = $path
                        break
                    }
                }
            }

            if (Test-Path $sourceFilePath) {
                Write-Host "  Processing: $sourceFileName"

                # Parse the PowerShell file using AST
                $errors = $null
                $tokens = $null
                $ast = [System.Management.Automation.Language.Parser]::ParseFile($sourceFilePath, [ref]$tokens, [ref]$errors)

                # Read the source file content for line analysis
                $noCovLines = @()

                $comments = $tokens.where({$_.Kind -eq 'Comment' -and $_.Text -match '#\s*nocov'})
                Write-Verbose "Found $($comments.Count) # nocov comments in $sourceFileName"
                $allStatements = $ast.FindAll({$args[0].GetType().Name -match 'Statement'}, $true)

                foreach ($comment in $comments) {
                    $allStatements | Where-Object { $_.Extent.StartLineNumber -eq $comment.Extent.StartLineNumber } | ForEach-Object {
                        # Add all lines from the statement to the noCovLines
                        Write-Verbose "Excluding block at lines $($_.Extent.StartLineNumber)..$($_.Extent.EndLineNumber) due to # nocov comment"
                        $noCovLines += ($_.Extent.StartLineNumber..$_.Extent.EndLineNumber)
                    }
                }

                # Remove duplicates and sort
                $noCovLines = $noCovLines | Sort-Object -Unique

                if ($noCovLines.Count -gt 0) {
                    Write-Host "    Excluding lines: $($noCovLines -join ', ')"

                    # Update the XML to mark these lines as covered (exclude from coverage)
                    foreach ($lineNum in $noCovLines) {
                        $lineElement = $sourceFile.SelectSingleNode("line[@nr='$lineNum']")
                        if ($lineElement) {
                            # Set missed instructions/branches to 0 and covered to 1 to exclude from coverage calculation
                            $lineElement.SetAttribute("mi", "0")
                            $lineElement.SetAttribute("mb", "0")
                            if ($lineElement.GetAttribute("ci") -eq "0") {
                                $lineElement.SetAttribute("ci", "1")
                            }
                            if ($lineElement.GetAttribute("cb") -eq "0") {
                                $lineElement.SetAttribute("cb", "0")
                            }
                        }
                    }
                }
            } else {
                Write-Warning "  Could not find source file: $sourceFileName"
            }
        }

        # Recalculate counters for classes and packages
        foreach ($class in $coverageXml.SelectNodes("//class")) {
            $allLines = $class.SelectNodes(".//line")
            $totalMissedInstructions = 0
            $totalCoveredInstructions = 0
            $totalMissedLines = 0
            $totalCoveredLines = 0

            foreach ($line in $allLines) {
                $mi = [int]$line.GetAttribute("mi")
                $ci = [int]$line.GetAttribute("ci")

                $totalMissedInstructions += $mi
                $totalCoveredInstructions += $ci

                if ($mi -gt 0) {
                    $totalMissedLines++
                } else {
                    $totalCoveredLines++
                }
            }

            # Update class counters
            $instructionCounter = $class.SelectSingleNode("counter[@type='INSTRUCTION']")
            if ($instructionCounter) {
                $instructionCounter.SetAttribute("missed", $totalMissedInstructions)
                $instructionCounter.SetAttribute("covered", $totalCoveredInstructions)
            }

            $lineCounter = $class.SelectSingleNode("counter[@type='LINE']")
            if ($lineCounter) {
                $lineCounter.SetAttribute("missed", $totalMissedLines)
                $lineCounter.SetAttribute("covered", $totalCoveredLines)
            }
        }

        # Save the updated XML
        $coverageXml.Save($CoverageFilePath)
        Write-Host "Coverage.xml updated successfully."
    }

    Update-CoverageXmlForNoCov -CoverageFilePath 'coverage.xml'
}
