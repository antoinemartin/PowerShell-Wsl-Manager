using namespace System.IO;
using module Pester;

# cSpell: ignore nand

[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseDeclaredVarsMoreThanAssignments', '')]
[Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
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
        Release = "3.22.1"
        Configured = $false
        Username = "root"
        Uid = 0
        LocalFilename = "docker.alpine-base.rootfs.tar.gz"
    },
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "alpine"
        Os = "Alpine"
        Url = "docker://ghcr.io/antoinemartin/PowerShell-Wsl-Manager/alpine#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Release = "3.22.1"
        Configured = $true
        Username = "alpine"
        Uid = 1000
    }
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "arch-base"
        Os = "Arch"
        Url = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch-base#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Release = "2025.08.01"
        Configured = $false
        Username = "root"
        Uid = 0
        LocalFilename = "docker.arch-base.rootfs.tar.gz"
    },
    [PSCustomObject]@{
        Type = "Builtin"
        Name = "arch"
        Os = "Arch"
        Url = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch#latest"
        Hash = [PSCustomObject]@{
            Type = "docker"
        }
        Release = "2025.08.01"
        Configured = $true
        Username = "arch"
        Uid = 1000
        LocalFilename = "docker.arch.rootfs.tar.gz"
    }
)

$MockIncus = @(
    [PSCustomObject]@{
        Type = "Incus"
        Name = "almalinux"
        Os = "almalinux"
        Url = "https://images.linuxcontainers.org/images/almalinux/8/amd64/default/20250816_23%3A08/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/almalinux/8/amd64/default/20250816_23%3A08/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Release = "8"
        LocalFileName = "incus.almalinux_8.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "almalinux"
        Os = "almalinux"
        Url = "https://images.linuxcontainers.org/images/almalinux/9/amd64/default/20250816_23%3A08/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/almalinux/9/amd64/default/20250816_23%3A08/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Release = "9"
        LocalFileName = "incus.almalinux_9.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "alpine"
        Os = "alpine"
        Url = "https://images.linuxcontainers.org/images/alpine/3.19/amd64/default/20250816_13%3A00/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/alpine/3.19/amd64/default/20250816_13%3A00/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Release = "3.19"
        LocalFileName = "incus.alpine_3.19.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    },
    [PSCustomObject]@{
        Type = "Incus"
        Name = "alpine"
        Os = "alpine"
        Url = "https://images.linuxcontainers.org/images/alpine/3.20/amd64/default/20250816_13%3A00/rootfs.tar.xz"
        Hash = [PSCustomObject]@{
            Algorithm = "SHA256"
            Url = "https://images.linuxcontainers.org/images/alpine/3.20/amd64/default/20250816_13%3A00/SHA256SUMS"
            Type = "sums"
            Mandatory = $true
        }
        Release = "3.20"
        LocalFileName = "incus.alpine_3.20.rootfs.tar.gz"
        Configured = $false
        Username = "root"
        Uid = 0
    }
)

$InvokeWebRequestUrlFilter = @'
$PesterBoundParameters.Uri -eq "{0}"
'@

$InvokeWebRequestUrlEtagFilter = @'
$PesterBoundParameters.Headers['If-None-Match'] -eq "{0}" -and $PesterBoundParameters.Uri -eq "{1}"
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
        'ETag' = @($Tag)
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
        [int]$Uid = 0
    )

    try {
        if ($null -eq $BasePath) {
            $BasePath = [WslImage]::BasePath
        }
        $tempDir = New-TemporaryDirectory
        $osReleasePath = (Join-Path -Path $tempDir.FullName -ChildPath "etc")
        $osReleaseFile = (Join-Path -Path $osReleasePath -ChildPath "os-release")
        $null = New-Item -Path $osReleasePath -ItemType Directory -Force
        $osReleaseContent = @"
BUILD_ID="$Release"
VERSION_ID="$Release"
ID="$($Os.ToLower())"
PRETTY_NAME="$Os $Release"
"@
        $null = Set-Content -Path $osReleaseFile -Value $osReleaseContent -Force

        $FullLocalFileName = Join-Path -Path $BasePath.FullName -ChildPath $LocalFileName
        & tar -czf $FullLocalFileName -C $tempDir.FullName . | Out-Null

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

        # Write image metadata to a Json file next to the tar.gz file
        $JsonFileName = "$FullLocalFileName.json"
        $JsonContent = $ImageHashtable | ConvertTo-Json
        $JsonContent | Set-Content -Path $JsonFileName -Force
        Write-Verbose "Created in $($BasePath.FullName) a mock image file $LocalFileName with os-release content:`n$osReleaseContent`nand metadata file $($JsonFileName):`n$JsonContent"
        return $ImageHashtable
    } finally {
        if ($null -ne $tempDir -and $tempDir.Exists) {
            # Clean up any previous temp directory
            $tempDir.Delete($true)
        }
    }
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
    'New-MockImage'
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
