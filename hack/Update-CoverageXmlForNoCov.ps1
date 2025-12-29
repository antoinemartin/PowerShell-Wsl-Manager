[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
[CmdletBinding()]
Param(
    [Parameter(Mandatory = $true)]
    [string]$CoverageFilePath
)

<#
.SYNOPSIS
    Post-processes coverage.xml to exclude lines marked with # nocov comments.

.DESCRIPTION
    This script updates a Pester code coverage XML file to exclude lines marked with
    "# nocov" comments from coverage calculations. It supports two types of exclusions:
    1. Individual line exclusion: Place "# nocov" at the end of any line
    2. Block exclusion: Place "# nocov" on the same line as an opening brace to exclude the entire block

.PARAMETER CoverageFilePath
    The path to the coverage.xml file to process.

.EXAMPLE
    .\Update-CoverageXmlForNoCov.ps1 -CoverageFilePath 'coverage.xml'

.NOTES
    This script parses PowerShell files using the AST (Abstract Syntax Tree) to identify
    statements that should be excluded from coverage based on # nocov comments.
#>

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
            ".\Wsl-SQLite\$sourceFileName",
            ".\Wsl-ImageSource\$sourceFileName"
        )

        foreach ($path in $possiblePaths) {
            if (Test-Path $path) {
                $sourceFilePath = $path
                break
            }
        }
    }

    if (Test-Path $sourceFilePath) {
        $actualSourceFilePath = (Get-Item $sourceFilePath).FullName
        Write-Host "  Processing: $actualSourceFilePath"

        # Parse the PowerShell file using AST
        $errors = $null
        $tokens = $null
        $ast = [System.Management.Automation.Language.Parser]::ParseFile($actualSourceFilePath, [ref]$tokens, [ref]$errors)

        # test if there were parsing errors
        if ($errors.Count -gt 0) {
            Write-Warning "    Skipping $sourceFileName due to parsing errors."
            # print errors
            foreach ($error in $errors) {
                Write-Warning "    Line $($error.Extent.StartLineNumber): $($error.Message)"
            }
            continue
        }

        # Read the source file content for line analysis
        $noCovLines = @()

        $comments = $tokens.where({$_.Kind -eq 'Comment' -and $_.Text -match '#\s*nocov'})
        Write-Host "    Found $($comments.Count) # nocov comments in $actualSourceFilePath"
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
