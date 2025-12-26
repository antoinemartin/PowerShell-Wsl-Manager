<#
.SYNOPSIS
    Generates markdown documentation files for all commands in a PowerShell module.

.DESCRIPTION
    This script builds reference documentation for a PowerShell module by generating individual markdown files
    for each command. The documentation is extracted using Get-Help and formatted as markdown with the help
    content enclosed in text code blocks. File names are generated in kebab-case format based on the command names.

.PARAMETER ModuleName
    The name of the PowerShell module for which to generate documentation. The module must be installed and
    available in the current session.

.PARAMETER DestinationDirectory
    The directory path where the generated markdown files will be saved. If the directory doesn't exist,
    it will be created automatically. Any existing markdown files in this directory will be removed before
    generating new documentation.

.EXAMPLE
    PS C:\> .\Invoke-ReferenceDocumentationBuild.ps1 -ModuleName "Wsl-Manager" -DestinationDirectory "C:\Docs\Reference"

    Generates documentation for all commands in the Wsl-Manager module and saves them to C:\Docs\Reference.

.EXAMPLE
    PS C:\> .\Invoke-ReferenceDocumentationBuild.ps1 -ModuleName "MyModule" -DestinationDirectory ".\docs"

    Generates documentation for MyModule and saves it to a docs subdirectory relative to the current location.

.NOTES
    - The script requires the target module to be installed and imported
    - Generated file names use kebab-case conversion (e.g., Get-WslImage becomes get-wsl-image.md)
    - All existing markdown files in the destination directory are removed before generating new documentation
    - Help content is retrieved using Get-Help with the -Full parameter for comprehensive documentation

.INPUTS
    None. You cannot pipe objects to this script.

.OUTPUTS
    None. The script generates markdown files in the specified destination directory.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$ModuleName,

    [Parameter(Mandatory = $true)]
    [string]$DestinationDirectory
)

# Function to convert PascalCase to kebab-case
function ConvertTo-KebabCase {
    param([string]$InputString)

    # Insert hyphens before uppercase letters (except the first one)
    $kebabCase = $InputString -creplace '(?<!^)([A-Z])', '-$1'
    # Remove multiple hyphens
    $kebabCase = $kebabCase -creplace '-{2,}', '-'
    # Convert to lowercase
    return $kebabCase.ToLower()
}

# Ensure destination directory exists
if (-not (Test-Path $DestinationDirectory)) {
    New-Item -Path $DestinationDirectory -ItemType Directory -Force | Out-Null
}

# Clear destination directory of all markdown files
Get-ChildItem -Path $DestinationDirectory -Filter "*.md" | Remove-Item -Force

# Get all commands from the specified module
try {
    $commands = Get-Command -Module $ModuleName -CommandType Function -ErrorAction Stop
}
catch {
    Write-Error "Failed to get commands from module '$ModuleName'. Make sure the module is installed and imported."
    return
}

# Generate documentation for each command
foreach ($command in $commands) {
    $commandName = $command.Name
    $kebabCaseName = ConvertTo-KebabCase -InputString $commandName
    $fileName = "$kebabCaseName.md"
    $filePath = Join-Path $DestinationDirectory $fileName

    # Get help documentation for the command
    try {
        $helpContent = Get-Help $commandName -Detailed | Out-String

        # Create markdown content with documentation in a text code block
        $markdownContent = @"
# $commandName

``````text
$helpContent
``````

"@

        # Remove spaces on empty lines to avoid rendering issues
        $markdownContent = ($markdownContent -split "`n") | ForEach-Object {
            if ($_ -match '^\s+$') {
                ''
            } else {
                $_ -replace '\s+$', ''
            }
        } | Out-String

        $markdownContent = $markdownContent.TrimEnd()
        # Write the markdown content to the file
        Set-Content -Path $filePath -Value $markdownContent -Force
    }
    catch {
        Write-Error "Failed to get help for command '$commandName'."
    }
}

# Generate an index.md file in the destination directory that contains a table
# with all Cmdlets with the following columns:
# - Command Name
# - Aliases
# - Description (only the first line)

$indexFilePath = Join-Path $DestinationDirectory "index.md"

# Create the index markdown content
$indexContent = @"
<!-- cSpell: disable -->
# $ModuleName Module Reference

| Command Name | Aliases | Description |
|--------------|---------|-------------|
"@

# Sort commands by noun (word after the hyphen)
$sortedCommands = $commands | Sort-Object { ($_.Name -split '-', 2)[1] }

foreach ($command in $sortedCommands) {
    $commandName = $command.Name

    # Get aliases for the command
    $aliases = (Get-Alias | Where-Object { $_.Definition -eq $commandName } | Select-Object -ExpandProperty Name) -join ", "
    if ([string]::IsNullOrEmpty($aliases)) {
        $aliases = "-"
    }

    # Get the first line of the synopsis/description
    try {
        $help = Get-Help $commandName -ErrorAction SilentlyContinue
        $description = if ($help.Synopsis) {
            ($help.Synopsis -split "`n")[0].Trim()
        } else {
            "No description available"
        }
    }
    catch {
        $description = "No description available"
    }

    # Create kebab-case link to the command's documentation file
    $kebabCaseName = ConvertTo-KebabCase -InputString $commandName

    # Add row to the table
    $indexContent += "`n| [$commandName]($kebabCaseName.md) | $aliases | $description |"
}

# Ensure the content ends with LF
$indexContent = $indexContent -replace "`r`n", "`n"

# Write the index file
Set-Content -Path $indexFilePath -Value $indexContent -Force

Write-Output "Generated documentation for $($commands.Count) commands and index file in '$DestinationDirectory'"
