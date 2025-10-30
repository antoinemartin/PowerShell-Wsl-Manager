using namespace System.IO;
using module Pester;

# cSpell: ignore nand

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPositionalParameters', '')]
Param()

function Emoji([string]$Code) {
    return [char]::ConvertFromUtf32([int]::Parse($Code, 'HexNumber'))
}

$testTube = Emoji "1F9EA" # Test tube emoji
$mock = Emoji "1F921" # Face with monocle emoji

function Write-Test {
    param (
        [string]$Message
    )
    Write-Host "$testTube $Message" -ForegroundColor DarkGray
}

New-Variable -Name MockPreference -Value $false -Option AllScope

function Write-Mock {
    param (
        [string]$Message
    )
    if ($MockPreference) {
        Write-Host "$mock $Message" -ForegroundColor DarkCyan
    }
}

function Set-MockPreference {
    param (
        [bool]$Value
    )
    $MockPreference = $Value
}

$MockETag = "MockedTag"
$MockModifiedETag = "NewMockedTag"
$MockBuiltins = @(
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "alpine-base"
        Os = "Alpine"
        Url = "docker://ghcr.io/antoinemartin/PowerShell-Wsl-Manager/alpine-base#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Digest = "0E5CC5702AD72A4E151F219976BA946D50161C3ACCE210EF3B122A529ABA1270"
        Release = "3.22.1"
        Configured = $false
        Username = "root"
        Uid = 0
        LocalFilename = "0E5CC5702AD72A4E151F219976BA946D50161C3ACCE210EF3B122A529ABA1270.rootfs.tar.gz"
    },
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "alpine"
        Os = "Alpine"
        Url = "docker://ghcr.io/antoinemartin/PowerShell-Wsl-Manager/alpine#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Digest = "C71610C3414076637103B80D044EE28B84235059A27AA5CE1C7E608513DB637D"
        Release = "3.22.1"
        Configured = $true
        Username = "alpine"
        Uid = 1000
        LocalFilename = "C71610C3414076637103B80D044EE28B84235059A27AA5CE1C7E608513DB637D.rootfs.tar.gz"
    }
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "arch-base"
        Os = "Arch"
        Url = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch-base#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Digest = "BDB4001A88E1430E5EB6F5B72F10D06B3824B4DB028BF25626AAD4B5099886D9"
        Release = "2025.08.01"
        Configured = $false
        Username = "root"
        Uid = 0
        LocalFilename = "BDB4001A88E1430E5EB6F5B72F10D06B3824B4DB028BF25626AAD4B5099886D9.rootfs.tar.gz"
    },
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "arch"
        Os = "Arch"
        Url = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Digest = "86362E88379865E68E2D78A82F0F8BF7964BBE901A28D125D7BDAE3AB6754FF2"
        Release = "2025.08.01"
        Configured = $true
        Username = "arch"
        Uid = 1000
        LocalFilename = "86362E88379865E68E2D78A82F0F8BF7964BBE901A28D125D7BDAE3AB6754FF2.rootfs.tar.gz"
    }
)

$MockIncus = @(
    [PSCustomObject]@{
        Type = "Incus"
        Name = "almalinux"
        Os = "Almalinux"
        Url = "https://images.linuxcontainers.org/images/almalinux/8/amd64/default/20250816_23%3A08/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/almalinux/8/amd64/default/20250816_23%3A08/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Digest = "57D3E23640D34CB632321C64C55CB4EA3DD90AE2BF5234A1E91648BA8B1D50F8"
        Release = "8"
        LocalFileName = "57D3E23640D34CB632321C64C55CB4EA3DD90AE2BF5234A1E91648BA8B1D50F8.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "almalinux"
        Os = "Almalinux"
        Url = "https://images.linuxcontainers.org/images/almalinux/9/amd64/default/20250816_23%3A08/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/almalinux/9/amd64/default/20250816_23%3A08/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Digest = "074E15D83CEFAFF85AC78AB9D3AC21972E7D136EF3FE0A5C23DAD486932D0E00"
        Release = "9"
        LocalFileName = "074E15D83CEFAFF85AC78AB9D3AC21972E7D136EF3FE0A5C23DAD486932D0E00.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "alpine"
        Os = "Alpine"
        Url = "https://images.linuxcontainers.org/images/alpine/3.19/amd64/default/20250816_13%3A00/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/alpine/3.19/amd64/default/20250816_13%3A00/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Digest = "A504665D9E4771E7933D9559FF8686C6AE3A3259DFBEE694255721210C298143"
        Release = "3.19"
        LocalFileName = "A504665D9E4771E7933D9559FF8686C6AE3A3259DFBEE694255721210C298143.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "alpine"
        Os = "Alpine"
        Url = "https://images.linuxcontainers.org/images/alpine/3.20/amd64/default/20250816_13%3A00/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/alpine/3.20/amd64/default/20250816_13%3A00/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Digest = "66950A256CF0866FA28B71B464255B47480E7A2C0C0DB11FE840A99E2BD13E44"
        Release = "3.20"
        LocalFileName = "66950A256CF0866FA28B71B464255B47480E7A2C0C0DB11FE840A99E2BD13E44.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    }
)

$InvokeWebRequestUrlFilter = @'
$PesterBoundParameters.Uri -eq "{0}"
'@

$InvokeWebRequestUrlEtagFilter = @'
($PesterBoundParameters.Headers -and $PesterBoundParameters.Headers['If-None-Match'] -eq "{0}") -and $PesterBoundParameters.Uri -eq "{1}"
'@

function New-WebResponseMock([object]$Content, [int]$StatusCode = 200, [hashtable]$Headers = $null) {
    $Response = New-MockObject -Type Microsoft.PowerShell.Commands.WebResponseObject
    Add-Member -InputObject $Response -MemberType NoteProperty -Name StatusCode -Value $StatusCode -Force
    Add-Member -InputObject $Response -MemberType NoteProperty -Name Content -Value $Content -Force
    if ($Headers) {
        Add-Member -InputObject $Response -MemberType NoteProperty -Name Headers -Value $Headers -Force
    }
    return $Response
}

function New-InvokeWebRequestMock([string]$SourceUrl, [object]$Content, [hashtable]$Headers = $null) {
    $Response = New-WebResponseMock -Content $Content -Headers $Headers

    Write-Test "Mocking source: $SourceUrl with content length: $($Content.Length)"
    # Filter script block needs to be created on the fly to pass SourceUrl and Tag as
    # literal values. There is apparently no better way to do this. (see https://github.com/pester/Pester/issues/1162)
    # GetNewClosure() cannot be used because we need to access $PesterBoundParameters that is not in the closure and defined
    # at a higher scope.
    $block = [scriptblock]::Create($InvokeWebRequestUrlFilter -f $SourceUrl)
    Mock Invoke-WebRequest { Write-Mock "Response for $($args | Where-Object { $_ -is [System.Uri] })"; return $Response }.GetNewClosure() -Verifiable -ParameterFilter $block -ModuleName Wsl-Manager

    return $Response
}

# Create A Mock WebException with the appropriate response
function New-WebExceptionMock([int]$StatusCode, [string]$Message, [hashtable]$Headers = $null) {
    $Response = New-MockObject -Type Microsoft.PowerShell.Commands.WebResponseObject
    Add-Member -InputObject $Response -MemberType NoteProperty -Name StatusCode -Value $StatusCode -Force
    Add-Member -InputObject $Response -MemberType NoteProperty -Name Content -Value $Message -Force
    Add-Member -InputObject $Response -MemberType NoteProperty -Name Headers -Value $Headers -Force

    $Exception = New-MockObject -Type System.Net.WebException
    Add-Member -InputObject $Exception -MemberType NoteProperty -Name Message -Value "Mocked WebException with http status $StatusCode and message '$Message'" -Force
    Add-Member -InputObject $Exception -MemberType NoteProperty -Name InnerException -Value (New-MockObject -Type System.Exception) -Force
    Add-Member -InputObject $Exception -MemberType NoteProperty -Name Response -Value $Response -Force

    return $Exception
}

function Add-InvokeWebRequestErrorMock([string]$SourceUrl, [int]$StatusCode, [string]$Message, [hashtable]$Headers = $null) {
    $Exception = New-WebExceptionMock -StatusCode $StatusCode -Message $Message -Headers $Headers
    $block = [scriptblock]::Create($InvokeWebRequestUrlFilter -f $SourceUrl)
    Mock Invoke-WebRequest { Write-Mock "$StatusCode Error for $($args | Where-Object { $_ -is [System.Uri] })"; throw $Exception }.GetNewClosure() -Verifiable -ParameterFilter $block -ModuleName Wsl-Manager
}

function New-SourceMock([string]$SourceUrl, [PSCustomObject[]]$Values, [string]$Tag){

    Write-Test "Mocking source: $SourceUrl with ETag: $Tag"
    $ResponseHeaders = @{
        'Content-Type' = 'application/json; charset=utf-8'
        'ETag' = $Tag
    }
    $Content = ($Values | ConvertTo-Json -Depth 10)

    New-InvokeWebRequestMock -SourceUrl $SourceUrl -Content $Content -Headers $ResponseHeaders

    $Exception = New-WebExceptionMock -StatusCode 304 -Message "Not Modified (Mock)" -Headers $ResponseHeaders

    $block = [scriptblock]::Create($InvokeWebRequestUrlEtagFilter -f @($Tag,$SourceUrl))

    Mock Invoke-WebRequest { Write-Mock "Not modified for $($args | Where-Object { $_ -is [System.Uri] })"; throw $Exception }.GetNewClosure() -Verifiable -ParameterFilter $block -ModuleName Wsl-Manager
}

$IncusSourceUrl = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json"
$BuiltinsSourceUrl = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json"

function New-BuiltinSourceMock($Tag = $MockETag) {
    New-SourceMock -SourceUrl $BuiltinsSourceUrl -Values $MockBuiltins -Tag $Tag
}

function New-IncusSourceMock($Tag = $MockETag) {
    New-SourceMock -SourceUrl $IncusSourceUrl -Values $MockIncus -Tag $Tag
}

function Get-FixtureContent($FixtureName) {
    $FixtureFilename = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "fixtures") -ChildPath $FixtureName
    return Get-Content -Path $FixtureFilename -Raw
}

function Add-InvokeWebRequestFixtureMock([string]$SourceUrl, [string]$fixtureName, [hashtable]$Headers = $null) {
    $FixtureFilename = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "fixtures") -ChildPath $fixtureName
    $Content = Get-Content -Path $FixtureFilename -Raw
    if ($FixtureFilename -match "\.json$") {
        # We assume the call is always done with -UseBasicParsing
        # $Content = $Content | ConvertFrom-Json
        if ($null -eq $Headers) {
            $Headers = @{
                'Content-Type' = 'application/json; charset=utf-8'
            }
        } else {
            $Headers['Content-Type'] = 'application/json; charset=utf-8'
        }
    }
    New-InvokeWebRequestMock -SourceUrl $SourceUrl -Content $Content -Headers $Headers
}

$EmptySha256 = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

function New-GetDockerImageMock() {
    Mock Get-DockerImage {
        Write-Mock "getting Docker image into $($DestinationFile)..."
        New-Item -Path $DestinationFile -ItemType File | Out-Null
        return $EmptySha256
    }  -ModuleName Wsl-Manager
}

function New-TemporaryDirectory {
    $tmp = [System.IO.Path]::GetTempPath() # Not $env:TEMP, see https://stackoverflow.com/a/946017
    $name = (New-Guid).ToString("N")
    New-Item -ItemType Directory -Path (Join-Path $tmp $name)
}

function New-MockImage {
    [CmdletBinding()]
    param (
        [System.IO.DirectoryInfo]$BasePath = $null,
        [string]$Name,
        [string]$Os = "Alpine",
        [string]$Type = "Builtin",
        [string]$Url = "docker://ghcr.io/antoinemartin/powerShell-wsl-manager/alpine#latest",
        [string]$Release = "3.22.1",
        [string]$LocalFileName = "docker.alpine.rootfs.tar.gz",
        [bool]$Configured = $false,
        [string]$Username,
        [int]$Uid = 0,
        [bool]$CreateWslConf = $false,
        [bool]$CreateMetadata = $true
    )

    try {
        if ($null -eq $BasePath) {
            $BasePath = [WslImage]::BasePath
        }
        $tempDir = New-TemporaryDirectory
        $etcDir = (Join-Path -Path $tempDir.FullName -ChildPath "etc")
        $osReleaseFile = (Join-Path -Path $etcDir -ChildPath "os-release")
        $null = New-Item -Path $etcDir -ItemType Directory -Force
        $osReleaseContent = @"
BUILD_ID="$Release"
VERSION_ID="$Release"
ID="$($Os.ToLower())"
PRETTY_NAME="$Os $Release"
"@
        $null = Set-Content -Path $osReleaseFile -Value $osReleaseContent -Force
        Write-Verbose "Created os-release file in $($osReleaseFile):`n$osReleaseContent"

        if ($Configured) {
            $wslConfiguredFile = (Join-Path -Path $etcDir -ChildPath "wsl-configured")
            $null = New-Item -Path $wslConfiguredFile -ItemType File -Force | Out-Null
            Write-Verbose "Created wsl-configured file in $($wslConfiguredFile)"
            if ($null -eq $Username) {
                $Username = $Os.ToLower()
                $Uid = 1000
            }
        }
        if ($Username) {
            $passwdFile = (Join-Path -Path $etcDir -ChildPath "passwd")
            $passwdContent = @"
$($Username):x:$($Uid):1000:$($Username):/home/$($Username):/bin/sh
"@
            $null = Set-Content -Path $passwdFile -Value $passwdContent -Force
            Write-Verbose "Created user $Username with UID $Uid in $($passwdFile):`n$passwdContent"
        }
        if ($CreateWslConf) {
            $wslConfFile = (Join-Path -Path $etcDir -ChildPath "wsl.conf")
            $wslConfContent = @"
[user]
default=$Username
"@
            $null = Set-Content -Path $wslConfFile -Value $wslConfContent -Force
        }
        $FullLocalFileName = Join-Path -Path $BasePath.FullName -ChildPath $LocalFileName
        & tar -czf $FullLocalFileName -C $tempDir.FullName etc | Out-Null
        Write-Verbose "Created in $($BasePath.FullName) a mock image file $LocalFileName"

        $FileHash = Get-FileHash -Path $FullLocalFileName -Algorithm SHA256
        $HashSource = @{
            Algorithm = "SHA256"
            Mandatory = $true
        }

        if (([System.Uri]$Url).Scheme -eq "docker") {
            $HashSource['Type'] = "docker"
        } else {
            $HashSource['Type'] = "sums"
        }

        $ImageHashtable = @{
            Os = $Os
            Type = $Type
            Url = $Url
            Release = $Release
            FileHash = $FileHash.Hash
            LocalFileName = $LocalFileName
            Configured = $Configured
            State = "Synced"
            HashSource = $HashSource
        }
        if ($Name) {
            $ImageHashtable['Name'] = $Name
        }
        if ($Username) {
            $ImageHashtable['Username'] = $Username
            $ImageHashtable['Uid'] = $Uid
        }

        if ($true -eq $CreateMetadata) {
            # Write image metadata to a Json file next to the tar.gz file
            $JsonFileName = "$FullLocalFileName.json"
            $JsonContent = $ImageHashtable | ConvertTo-Json
            $JsonContent | Set-Content -Path $JsonFileName -Force
            Write-Verbose "Created $($BasePath.FullName) a metadata file $JsonFileName with content:`n$JsonContent"
        }
        return $ImageHashtable
    } finally {
        if ($null -ne $tempDir -and $tempDir.Exists) {
            # Clean up any previous temp directory
            $tempDir.Delete($true)
        }
    }
}

$DockerHubRegistryDomain = "registry-1.docker.io"

function Get-DockerAuthTokenUrl($Repository, $Registry = "ghcr.io") {
    if ($Registry -eq "ghcr.io") {
        return "https://$Registry/token?service=$Registry&scope=repository:$($Repository):pull"
    } elseif ($Registry -eq $DockerHubRegistryDomain) {
        return "https://auth.docker.io/token?service=registry.docker.io&scope=repository:$($Repository):pull"
    } else {
        throw "Unsupported registry: $Registry"
    }
}
function Get-DockerIndexUrl($Repository, $Tag, $Registry = "ghcr.io") {
    return "https://$Registry/v2/$Repository/manifests/$Tag"
}
function Get-DockerBlobUrl($Repository, $Digest, $Registry = "ghcr.io") {
    $result = "https://$Registry/v2/$Repository/blobs/$Digest"
    return $result
}
function Get-DockerManifestUrl($Repository, $Digest, $Registry = "ghcr.io") {
    return "https://$Registry/v2/$Repository/manifests/$Digest"
}
function Get-FixtureFilename($Repository, $Tag, $Suffix=$null) {
    $safeRepo = $Repository -replace '[\/:]', '_slash_'
    $realSuffix = if ($Suffix) { "_$Suffix" } else { "" }
    return "docker_$($safeRepo)_colon_$($Tag)$realSuffix.json"
}

function Add-DockerImageMock($Repository, $Tag, $Registry = "ghcr.io") {
    $authFixture = Get-FixtureFilename $Repository $Tag "token"
    $indexFixture = Get-FixtureFilename $Repository $Tag "index"
    $manifestFixture = Get-FixtureFilename $Repository $Tag "manifest"
    $configFixture = Get-FixtureFilename $Repository $Tag "config"

    $index = Get-FixtureContent $indexFixture | ConvertFrom-Json
    $manifestDigest = ($index.manifests | Where-Object { $_.platform.architecture -eq 'amd64' }).digest

    $manifest = Get-FixtureContent $manifestFixture | ConvertFrom-Json
    $configDigest = $manifest.config.digest

    $authUrl = Get-DockerAuthTokenUrl $Repository $Registry
    $indexUrl = Get-DockerIndexUrl $Repository $Tag $Registry
    $manifestUrl = Get-DockerManifestUrl $Repository $manifestDigest $Registry
    $configUrl = Get-DockerBlobUrl $Repository $configDigest $Registry

    Add-InvokeWebRequestFixtureMock -SourceUrl $authUrl -FixtureName $authFixture | Out-Null
    Add-InvokeWebRequestFixtureMock -SourceUrl $indexUrl -FixtureName $indexFixture -Headers @{ "Content-Type" = "application/vnd.docker.distribution.manifest.list.v2+json" } | Out-Null
    Add-InvokeWebRequestFixtureMock -SourceUrl $manifestUrl -FixtureName $manifestFixture -Headers @{ "Content-Type" = "application/vnd.docker.distribution.manifest.v2+json" } | Out-Null
    Add-InvokeWebRequestFixtureMock -SourceUrl $configUrl -FixtureName $configFixture -Headers @{ "Content-Type" = "application/vnd.docker.distribution.config.v1+json" } | Out-Null
    return $manifest.layers[0].digest
}

function Add-DockerImageFailureMock($Repository, $Tag, $StatusCode) {
    $authUrl = Get-DockerAuthTokenUrl $Repository
    $indexUrl = Get-DockerIndexUrl $Repository $Tag

    $authFixture = Get-FixtureFilename $Repository $Tag "token"
    Add-InvokeWebRequestFixtureMock -SourceUrl $authUrl -FixtureName $authFixture | Out-Null
    Add-InvokeWebRequestErrorMock -SourceUrl $indexUrl -StatusCode $StatusCode -Message "Mocked $StatusCode error for $($Repository):$Tag" | Out-Null
}

function Add-GetDockerImageManifestMock($Repository, $Tag, $Registry = "ghcr.io") {
    $fixtureName = Get-FixtureFilename( $Repository, $Tag )
    $FixtureFilename = Join-Path -Path (Join-Path -Path $PSScriptRoot -ChildPath "fixtures") -ChildPath $fixtureName
    $Content = Get-Content -Path $FixtureFilename -Raw

    Mock -Command-Name Get-GetDockerImageManifest {
        Write-Mock "getting Docker image into $($DestinationFile)..."
        New-Item -Path $DestinationFile -ItemType File | Out-Null
        return $EmptySha256
    }  -ModuleName Wsl-Manager
}

$FunctionsToExport = @(
    'Write-Test',
    'Write-Mock',
    'New-SourceMock',
    'New-BuiltinSourceMock',
    'New-IncusSourceMock',
    'New-GetDockerImageMock',
    'Set-MockPreference',
    'New-InvokeWebRequestMock',
    'Add-InvokeWebRequestFixtureMock',
    'Add-InvokeWebRequestErrorMock',
    'Get-FixtureContent',
    'New-MockImage',
    'Get-FixtureFilename',
    'Get-DockerAuthTokenUrl',
    'Get-DockerIndexUrl',
    'Get-DockerBlobUrl',
    'Get-DockerManifestUrl',
    'Add-DockerImageMock',
    'Add-DockerImageFailureMock'
)

$VariablesToExport = @(
    'MockETag',
    'MockModifiedETag',
    'MockBuiltins',
    'MockIncus',
    'EmptySha256',
    'MockPreference',
    'IncusSourceUrl',
    'BuiltinsSourceUrl'
)

Export-ModuleMember -Function $FunctionsToExport
Export-ModuleMember -Variable $VariablesToExport
