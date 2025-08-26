$ContentToAdd = try {
    (Invoke-WebRequest -Uri "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/main/docs/examples/docker_profile.ps1" -UseBasicParsing).Content
} catch {
    Get-Content $PSScriptRoot\docker_profile.ps1 -Raw
}
$StartComment = "### START Adding Docker alias"
$EndComment = "### END Adding Docker alias"

# Get $PROFILE, Remove existing Docker alias and add new one
$NewBlock = "`n$StartComment`n$ContentToAdd`n$EndComment`n"
if (Test-Path -Path $PROFILE) {
    $ProfileContent = Get-Content -Path $PROFILE -Raw
    # Remove existing block
    $Pattern = [regex]::Escape($StartComment) + '.*?' + [regex]::Escape($EndComment)
    $ProfileContent = [regex]::Replace($ProfileContent, $Pattern, '', [System.Text.RegularExpressions.RegexOptions]::Singleline)
    # Append new block
    $UpdatedContent = $ProfileContent + $NewBlock
    Set-Content -Path $PROFILE -Value $UpdatedContent
} else {
    # Create new profile with the Docker alias block
    New-Item -Path $PROFILE -ItemType File -Force
    Set-Content -Path $PROFILE -Value $NewBlock
}
