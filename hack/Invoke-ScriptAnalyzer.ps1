[CmdletBinding()]
param(
    [Parameter(Mandatory = $true, Position = 0, ValueFromRemainingArguments)]
    [string[]]$FileNames
)

Import-Module PSScriptAnalyzer

$violations = @()

# Uncomment this to generate some violation
# $generate_violation = ""

$FileNames | ForEach-Object {
    $violations +=  Invoke-ScriptAnalyzer -Settings PSGallery -Path $_
}

if ($violations.Count -gt 0) {
    Write-Output -InputObject $violations
    exit 1
} else {
    exit 0
}
