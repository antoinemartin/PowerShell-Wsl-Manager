[CmdletBinding()]
param(
    [switch]$Upload,
    [string]$Version,
    [string]$ApiKey
)

if (-not (Get-InstalledModule -Name PowerShellGet -ErrorAction SilentlyContinue | Where-Object { $_.Version -eq '3.0.23-beta23' })) {
    Write-Host "Installing PowerShellGet 3..."
    # Ensuring PowerShellGet stable is latest version
    Install-Module -Name PowerShellGet -Force -AllowClobber
    # Installing PowerShellGet 3 Prerelease
    # Pinned to old version due to https://github.com/PowerShell/PowerShellGet/issues/835
    Install-Module -Name PowerShellGet -RequiredVersion 3.0.23-beta23 -AllowPrerelease -Force -Repository PSGallery -SkipPublisherCheck
} else {
    Write-Host "PowerShellGet 3 is already installed."
}

if (Test-Path repo) {
    Write-Host "Removing existing local NuGet repository..."
    Remove-Item repo -Recurse -Force
}

$LocalRepo = New-Item repo -Type Directory

if (-not (Get-PSResourceRepository -Name "LocalRepo" -ErrorAction SilentlyContinue)) {
    Write-Host "Registering local NuGet repository..."
    Register-PSResourceRepository -Name "LocalRepo" -Uri $LocalRepo.FullName
} else {
    Write-Host "Local NuGet repository already registered."
}

$modulePath = "/tmp/$(New-Guid)/Wsl-Manager"
try {
    Write-Host "Creating Release in $modulePath..."
    New-Item $modulePath -ItemType Directory -Force | Out-Null

    $packageFiles = Import-PowerShellDataFile .\Wsl-Manager.psd1 |`
    Select-Object -Property RootModule,FileList,TypesToProcess,FormatsToProcess |`
    ForEach-Object { @($_.RootModule) + $_.FileList + $_.TypesToProcess + $_.FormatsToProcess }
    $packageFiles = $packageFiles + @('Wsl-Manager.psd1')

    $packageFiles | ForEach-Object {
        # Create parent directory structure
        $parentDir = Join-Path -Path $modulePath -ChildPath (Split-Path -Path $_ -Parent)
        New-Item -Path $parentDir -ItemType Directory -Force | Out-Null
        Copy-Item $_ -Destination $parentDir -Force
        Write-Verbose "$_ copied to $parentDir"
    }

    # ensure that at destination, configure.sh and p10k.zsh are LF ended
    Get-ChildItem -Path $modulePath -Recurse -Include configure.sh, p10k.zsh | ForEach-Object {
        (Get-Content $_.FullName -Raw) -replace "`r`n", "`n" | Set-Content $_.FullName
    }
    if ($Version -and $Version -match '^v\d+\.\d+\.\d+$') {
        $SemVer=$Version -replace '^v', ''
        Get-Content .\Wsl-Manager.psd1 | ForEach-Object { $_ -replace 'ModuleVersion(\s+)=(\s+)''\d+\.\d+\.\d+''', "ModuleVersion`$1=`$2'$SemVer'" }  | Set-Content $modulePath\Wsl-Manager.psd1
    }

    Write-Host "Publishing to local NuGet repository..."
    Publish-PSResource -Path $modulePath -Repository "LocalRepo"

    if ($Upload) {
        if (-not $ApiKey) {
            Write-Host "API key is required for uploading."
            return
        }
        Write-Host "Uploading package to NuGet.org..."
        Publish-PSResource -Path $modulePath -Repository "PSGallery" -ApiKey $ApiKey
    }

} finally {
    Remove-Item $modulePath -Recurse -Force
    Unregister-PSResourceRepository -Name "LocalRepo" -ErrorAction SilentlyContinue  | Out-Null
}
