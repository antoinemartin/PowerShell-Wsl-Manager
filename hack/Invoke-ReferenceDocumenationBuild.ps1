# Parameters:
# - Module Name
# - Destination directory
# Steps:
# - Clear the destination directory from all markdown (*.md) files.
# - For each command in the module, generate a markdown file with the command's documentation.
#   The documentation is enclosed in a ```text``` block. It is retrieved by Get-Help <CommandName>.
#   The name of the Markdown file is the name of the command in kebab case. For instance,
#   Get-WslRootFileSystem becomes get-wsl-root-file-system.md.
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
    $commands = Get-Command -Module $ModuleName -ErrorAction Stop
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
        $helpContent = Get-Help $commandName -Full | Out-String

        # Create markdown content with documentation in a text code block
        $markdownContent = @"
# $commandName

``````text
$helpContent
``````

"@
        # Write the markdown content to the file
        Set-Content -Path $filePath -Value $markdownContent -Force
    }
    catch {
        Write-Error "Failed to get help for command '$commandName'."
    }
}
