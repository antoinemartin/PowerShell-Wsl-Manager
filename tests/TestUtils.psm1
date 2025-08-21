using module Pester;

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

function New-SourceMock([string]$SourceUrl, [PSCustomObject[]]$Values, [string]$Tag){

    Write-Test "Mocking source: $SourceUrl with ETag: $Tag"
    $Response = New-MockObject -Type Microsoft.PowerShell.Commands.WebResponseObject
    $Response | Add-Member -MemberType NoteProperty -Name StatusCode -Value 200 -Force
    $ResponseHeaders = @{
        'Content-Type' = 'application/json; charset=utf-8'
        'ETag' = @($Tag)
    }
    $Response | Add-Member -MemberType NoteProperty -Name Headers -Value $ResponseHeaders -Force
    $Response | Add-Member -MemberType NoteProperty -Name Content -Value ($Values | ConvertTo-Json -Depth 10) -Force

    # Filter script block needs to be created on the fly to pass SourceUrl and Tag as
    # literal values. There is apparently no better way to do this. (see https://github.com/pester/Pester/issues/1162)
    # GetNewClosure() cannot be used because we need to access $PesterBoundParameters that is not in the closure and defined
    # at a higher scope.
    $block = [scriptblock]::Create($InvokeWebRequestUrlFilter -f $SourceUrl)

    # GetNewClosure() will create a closure that captures the current value of $Response
    Mock Invoke-WebRequest { Write-Mock "Response for $($args | Where-Object { $_ -is [System.Uri] })"; return $Response }.GetNewClosure() -Verifiable -ParameterFilter $block -ModuleName Wsl-Manager

    $NotModifiedResponse = New-MockObject -Type Microsoft.PowerShell.Commands.WebResponseObject
    $NotModifiedResponse | Add-Member -MemberType NoteProperty -Name StatusCode -Value 304 -Force
    $NotModifiedResponse | Add-Member -MemberType NoteProperty -Name Headers -Value $ResponseHeaders -Force
    $NotModifiedResponse | Add-Member -MemberType NoteProperty -Name Content -Value "" -Force

    $block = [scriptblock]::Create($InvokeWebRequestUrlEtagFilter -f @($Tag,$SourceUrl))

    $Exception = New-MockObject -Type System.Net.WebException
    $Exception | Add-Member -MemberType NoteProperty -Name Message -Value "Not Modified (Mock)" -Force
    $Exception | Add-Member -MemberType NoteProperty -Name InnerException -Value (New-MockObject -Type System.Exception) -Force
    $Exception | Add-Member -MemberType NoteProperty -Name Response -Value $NotModifiedResponse -Force

    Mock Invoke-WebRequest { Write-Mock "Not modified for $($args | Where-Object { $_ -is [System.Uri] })"; throw $Exception }.GetNewClosure() -Verifiable -ParameterFilter $block -ModuleName Wsl-Manager
}

$IncusSourceUrl = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json"
$BuiltinsSourceUrl = "https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json"

Function New-BuiltinSourceMock($Tag = $MockETag) {
    New-SourceMock -SourceUrl $BuiltinsSourceUrl -Values $MockBuiltins -Tag $Tag
}

Function New-IncusSourceMock($Tag = $MockETag) {
    New-SourceMock -SourceUrl $IncusSourceUrl -Values $MockIncus -Tag $Tag
}

$EmptySha256 = "E3B0C44298FC1C149AFBF4C8996FB92427AE41E4649B934CA495991B7852B855"

function New-GetDockerImageMock() {
    Mock Get-DockerImage {
        Write-Mock "getting Docker image into $($DestinationFile)..."
        New-Item -Path $DestinationFile -ItemType File | Out-Null
        return $EmptyHash
    }  -ModuleName Wsl-Manager
}


Export-ModuleMember -Function Write-Test, Write-Mock, New-SourceMock, New-BuiltinSourceMock, New-IncusSourceMock, New-GetDockerImageMock, Set-MockPreference
Export-ModuleMember -Variable MockETag, MockModifiedETag, MockBuiltins, MockIncus, EmptySha256, MockPreference
