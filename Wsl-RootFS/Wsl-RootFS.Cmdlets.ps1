function New-WslImageHash {
    <#
    .SYNOPSIS
    Creates a new FileSystem hash holder.

    .DESCRIPTION
    The WslImageHash object holds checksum information for one or more
    distributions in order to check it upon download and determine if the filesystem
    has been updated.

    Note that the checksums are not downloaded until the `Retrieve()` method has been
    called on the object.

    .PARAMETER Url
    The Url where the checksums are located.

    .PARAMETER Algorithm
    The checksum algorithm. Nowadays, we find mostly SHA256.

    .PARAMETER Type
    Type can either be `sums` in which case the file contains one
    <checksum> <filename> pair per line, or `single` and just contains the hash for
    the file which name is the last segment of the Url minus the extension. For
    instance, if the URL is `https://.../rootfs.tar.xz.sha256`, we assume that the
    checksum it contains is for the file named `rootfs.tar.xz`.

    .EXAMPLE
    New-WslImageHash https://cloud-images.ubuntu.com/wsl/noble/current/SHA256SUMS
    Creates the hash source for several files with SHA256 (default) algorithm.

    .EXAMPLE
    New-WslImageHash https://.../rootfs.tar.xz.sha256 -Type `single`
    Creates the hash source for the rootfs.tar.xz file with SHA256 (default) algorithm.

    .NOTES
    General notes
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,
        [Parameter(Mandatory = $false)]
        [string]$Algorithm = 'SHA256',
        [Parameter(Mandatory = $false)]
        [string]$Type = 'sums'
    )

    return [WslImageHash]@{
        Url       = $Url
        Algorithm = $Algorithm
        Type      = $Type
    }

}

function New-WslImage {
    <#
    .SYNOPSIS
    Creates a WslImage object.

    .DESCRIPTION
    WslImage object retrieve and provide information about available root
    filesystems.

    .PARAMETER Distribution
    The identifier of the distribution. It can be an already known name:
    - Arch
    - Alpine
    - Ubuntu
    - Debian

    It also can be the URL (https://...) of an existing filesystem or a
    distribution name saved through Export-WslInstance.

    It can also be a name in the form:

        incus:<os>:<release> (ex: incus:rockylinux:9)

    In this case, it will fetch the last version the specified image in
    https://images.linuxcontainers.org/images.

    .PARAMETER Configured
    Whether the distribution is configured. This parameter is relevant for Builtin
    distributions.

    .PARAMETER Path
    The path of the root filesystem. Should be a file ending with `rootfs.tar.gz`.
    It will try to extract the OS and Release from the filename (in /etc/os-release).

    .PARAMETER File
    A FileInfo object of the compressed root filesystem.

    .EXAMPLE
    New-WslImage incus:alpine:3.19
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    The WSL root filesystem representing the incus alpine 3.19 image.

    .EXAMPLE
    New-WslImage alpine -Configured
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
    The builtin configured Alpine root filesystem.

    .EXAMPLE
    New-WslImage test.rootfs.tar.gz
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.21.3                   Synced test.rootfs.tar.gz
    The The root filesystem from the file.

    .LINK
    Get-WslImage
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Distribution,
        [Parameter(ParameterSetName = 'Path', ValueFromPipeline = $true, Mandatory = $true)]
        [string]$Path,
        [Parameter(ParameterSetName = 'File', ValueFromPipeline = $true, Mandatory = $true)]
        [FileInfo]$File
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            return [WslImage]::new($Distribution)
        }
        else {
            if ($PSCmdlet.ParameterSetName -eq "Path") {
                $Path = Resolve-Path $Path
                $File = [FileInfo]::new($Path)
            }
            return [WslImage]::new($File)
        }
    }

}

function Sync-WslImage {
    <#
    .SYNOPSIS
    Synchronize locally the specified WSL root filesystem.

    .DESCRIPTION
    If the root filesystem is not already present locally, downloads it from its
    original URL.

    .PARAMETER Distribution
    The identifier of the distribution. It can be an already known name:
    - Arch
    - Alpine
    - Ubuntu
    - Debian

    It also can be the URL (https://...) of an existing filesystem or a
    distribution name saved through Export-WslInstance.

    It can also be a name in the form:

        incus:<os>:<release> (ex: incus:rockylinux:9)

    In this case, it will fetch the last version the specified image in
    https://images.linuxcontainers.org/images.

    .PARAMETER Image
    The WslImage object to process.

    .PARAMETER Force
    Force the synchronization even if the root filesystem is already present locally.

    .INPUTS
    The WslImage Objects to process.

    .OUTPUTS
    The path of the WSL root filesystem. It is suitable as input for the
    `wsl --import` command.

    .EXAMPLE
    Sync-WslImage Alpine -Configured
    Syncs the already configured builtin Alpine root filesystem.

    .EXAMPLE
    Sync-WslImage Alpine -Force
    Re-download the Alpine builtin root filesystem.

    .EXAMPLE
    Get-WslImage -State NotDownloaded -Os Alpine | Sync-WslImage
    Synchronize the Alpine root filesystems not already synced

    .EXAMPLE
     New-WslImage alpine -Configured | Sync-WslImage | % { &wsl --import test $env:LOCALAPPDATA\Wsl\test $_ }
     Create a WSL distro from a synchronized root filesystem.

    .LINK
    New-WslImage
    Get-WslImage
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Distribution,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Image")]
        [WslImage[]]$Image,
        [Parameter(Mandatory = $true, ParameterSetName = "Path")]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Image = $Distribution | ForEach-Object { New-WslImage -Distribution $_ }
        }
        if ($PSCmdlet.ParameterSetName -eq "Path") {
            $Image = New-WslImage -Path $Path
        }

        if ($null -ne $Image) {
            $Image | ForEach-Object {
                $fs = $_
                [FileInfo] $dest = $fs.File

                If (!([WslImage]::BasePath.Exists)) {
                    if ($PSCmdlet.ShouldProcess([WslImage]::BasePath.Create(), "Create base path")) {
                        Progress "Creating Image base path [$([WslImage]::BasePath)]..."
                        [WslImage]::BasePath.Create()
                    }
                }

                if (!$dest.Exists -Or $_.Outdated -Or $true -eq $Force) {
                    if ($PSCmdlet.ShouldProcess($fs.Url, "Sync locally")) {
                        try {
                            $fs.FileHash = $fs.GetHashSource().DownloadAndCheckFile($fs.Url, $fs.File)
                        }
                        catch [Exception] {
                            throw [WslManagerException]::new("Error while loading distro [$($fs.OsName)] on $($fs.Url): $($_.Exception.Message)", $_.Exception)
                            return $null
                        }
                        $fs.State = [WslImageState]::Synced
                        $fs.WriteMetadata()
                        Success "[$($fs.OsName)] Synced at [$($dest.FullName)]."
                    }
                }
                else {
                    Information "[$($fs.OsName)] Root FS already at [$($dest.FullName)]."
                }

                return $dest.FullName
            }

        }
    }

}


function Get-WslImage {
    <#
    .SYNOPSIS
        Gets the WSL root filesystems installed on the computer and the ones available.
    .DESCRIPTION
        The Get-WslImage cmdlet gets objects that represent the WSL root filesystems available on the computer.
        This can be the ones already synchronized as well as the Builtin filesystems available.
    .PARAMETER Name
        Specifies the name of the filesystem.
    .PARAMETER Os
        Specifies the Os of the filesystem.
    .PARAMETER Type
        Specifies the type of the filesystem.
    .PARAMETER Outdated
        Return the list of outdated root filesystems. Works mainly on Builtin
        distributions.
    .INPUTS
        System.String
        You can pipe a distribution name to this cmdlet.
    .OUTPUTS
        WslImage
        The cmdlet returns objects that represent the WSL root filesystems on the computer.
    .EXAMPLE
        Get-WslImage
           Type Os           Release                 State Name
           ---- --           -------                 ----- ----
        Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
        Builtin Arch         current                Synced arch.rootfs.tar.gz
        Builtin Debian       bookworm               Synced debian.rootfs.tar.gz
          Local Docker       unknown                Synced docker.rootfs.tar.gz
          Local Flatcar      unknown                Synced flatcar.rootfs.tar.gz
        Incus almalinux      8                      Synced incus.almalinux_8.rootfs.tar.gz
        Incus almalinux      9                      Synced incus.almalinux_9.rootfs.tar.gz
        Incus alpine         3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
        Incus alpine         edge                   Synced incus.alpine_edge.rootfs.tar.gz
        Incus centos         9-Stream               Synced incus.centos_9-Stream.Image.ta...
        Incus opensuse       15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
        Incus rockylinux     9                      Synced incus.rockylinux_9.rootfs.tar.gz
        Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
        Builtin Arch         current                Synced miniwsl.arch.rootfs.tar.gz
        Builtin Debian       bookworm               Synced miniwsl.debian.rootfs.tar.gz
        Builtin Opensuse     tumbleweed             Synced miniwsl.opensuse.rootfs.tar.gz
        Builtin Ubuntu       noble           NotDownloaded miniwsl.ubuntu.rootfs.tar.gz
          Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
        Builtin Opensuse     tumbleweed             Synced opensuse.rootfs.tar.gz
          Local Out          unknown                Synced out.rootfs.tar.gz
          Local Postgres     unknown                Synced postgres.rootfs.tar.gz
        Builtin Ubuntu       noble                  Synced ubuntu.rootfs.tar.gz
        Get all WSL root filesystem.

    .EXAMPLE
        Get-WslImage -Os alpine
           Type Os           Release                 State Name
           ---- --           -------                 ----- ----
        Builtin Alpine       3.19            NotDownloaded alpine.rootfs.tar.gz
          Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
          Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
        Builtin Alpine       3.19                   Synced miniwsl.alpine.rootfs.tar.gz
        Get All Alpine root filesystems.
    .EXAMPLE
        Get-WslImage -Type Incus
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        Incus almalinux    8                      Synced incus.almalinux_8.rootfs.tar.gz
        Incus almalinux    9                      Synced incus.almalinux_9.rootfs.tar.gz
        Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
        Incus alpine       edge                   Synced incus.alpine_edge.rootfs.tar.gz
        Incus centos       9-Stream               Synced incus.centos_9-Stream.Image.ta...
        Incus opensuse     15.4                   Synced incus.opensuse_15.4.rootfs.tar.gz
        Incus rockylinux   9                      Synced incus.rockylinux_9.rootfs.tar.gz
        Get All downloaded Incus root filesystems.
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory = $false)]
        [string]$Os,
        [Parameter(Mandatory = $false)]
        [WslImageSource]$Source = [WslImageSource]::Local,
        [Parameter(Mandatory = $false)]
        [WslImageState]$State,
        [Parameter(Mandatory = $false)]
        [WslImageType]$Type,
        [Parameter(Mandatory = $false)]
        [switch]$Configured,
        [Parameter(Mandatory = $false)]
        [switch]$Outdated
    )

    process {
        $fileSystems = @()
        if ($Source -band [WslImageSource]::Local) {
            $fileSystems += [WslImage]::LocalFileSystems()
        }
        if ($Source -band [WslImageSource]::Builtins) {
            $fileSystems += Get-WslBuiltinImage -Source Builtins
        }
        if ($Source -band [WslImageSource]::Incus) {
            $fileSystems += Get-WslBuiltinImage -Source Incus
        }
        $fileSystems = $fileSystems | Sort-Object | Select-Object -Unique

        if ($PSBoundParameters.ContainsKey("Type")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.Type -eq $Type
            }
        }

        if ($PSBoundParameters.ContainsKey("Os")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.Os -eq $Os
            }
        }

        if ($PSBoundParameters.ContainsKey("State")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.State -eq $State
            }
        }

        if ($PSBoundParameters.ContainsKey("Configured")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.Configured -eq $Configured.IsPresent
            }
        }

        if ($PSBoundParameters.ContainsKey("Outdated")) {
            $fileSystems = $fileSystems | Where-Object {
                $_.Outdated
            }
        }

        if ($Name.Length -gt 0) {
            $fileSystems = $fileSystems | Where-Object {
                foreach ($pattern in $Name) {
                    Write-Verbose "Checking pattern: $pattern against $($_.Name)"
                    if ($_.Name -ilike $pattern -or $_.Name -imatch "(\w+\.)?$pattern\.rootfs\.tar\.gz") {
                        return $true
                    }
                }

                return $false
            }
            if ($null -eq $fileSystems) {
                throw [UnknownWslImageException]::new($Name)
            }
        }

        return $fileSystems
    }
}


<#
.SYNOPSIS
Remove a WSL root filesystem from the local disk.

.DESCRIPTION
If the WSL root filesystem in synced, it will remove the tar file and its meta
data from the disk. Builtin root filesystems will still appear as output of
`Get-WslImage`, but their state will be `NotDownloaded`.

.PARAMETER Distribution
The identifier of the distribution. It can be an already known name:
- Arch
- Alpine
- Ubuntu
- Debian

It also can be the URL (https://...) of an existing filesystem or a
distribution name saved through Export-WslInstance.

It can also be a name in the form:

    incus:<os>:<release> (ex: incus:rockylinux:9)

In this case, it will fetch the last version the specified image in
https://images.linuxcontainers.org/images.


.PARAMETER Image
The WslImage object representing the WSL root filesystem to delete.

.INPUTS
One or more WslImage objects representing the WSL root filesystem to
delete.

.OUTPUTS
The WslImage objects updated.

.EXAMPLE
Remove-WslImage alpine -Configured
Removes the builtin configured alpine root filesystem.

.EXAMPLE
New-WslImage "incus:alpine:3.19" | Remove-WslImage
Removes the Incus alpine 3.19 root filesystem.

.EXAMPLE
Get-WslImage -Type Incus | Remove-WslImage
Removes all the Incus root filesystems present locally.

.Link
Get-WslImage
New-WslImage
#>
Function Remove-WslImage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Image")]
        [WslImage[]]$Image
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Image = Get-WslImage -Name $Name
        }

        if ($null -ne $Image) {
            $Image | ForEach-Object {
                if ($_.Delete()) {
                    $_
                }
            }
        }
    }
}

<#
.SYNOPSIS
Get the list of available Incus based root filesystems.

.DESCRIPTION
This command retrieves the list of available Incus root filesystems from the
Canonical site: https://images.linuxcontainers.org/imagesstreams/v1/index.json


.PARAMETER Name
List of names or wildcard based patterns to select the Os.


.EXAMPLE
Get-IncusImage
Retrieve the complete list of Incus root filesystems

.EXAMPLE
 Get-IncusImage alma*

Os        Release
--        -------
almalinux 8
almalinux 9

Get all alma based filesystems.

.EXAMPLE
Get-IncusImage mint | %{ New-WslImage "incus:$($_.Os):$($_.Release)" }

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
     Incus mint         tara            NotDownloaded incus.mint_tara.rootfs.tar.gz
     Incus mint         tessa           NotDownloaded incus.mint_tessa.rootfs.tar.gz
     Incus mint         tina            NotDownloaded incus.mint_tina.rootfs.tar.gz
     Incus mint         tricia          NotDownloaded incus.mint_tricia.rootfs.tar.gz
     Incus mint         ulyana          NotDownloaded incus.mint_ulyana.rootfs.tar.gz
     Incus mint         ulyssa          NotDownloaded incus.mint_ulyssa.rootfs.tar.gz
     Incus mint         uma             NotDownloaded incus.mint_uma.rootfs.tar.gz
     Incus mint         una             NotDownloaded incus.mint_una.rootfs.tar.gz
     Incus mint         vanessa         NotDownloaded incus.mint_vanessa.rootfs.tar.gz

Get all mint based Incus root filesystems as WslImage objects.

#>
function Get-IncusImage {
    [CmdletBinding()]
    param (
        [Parameter(Mandatory = $false, ValueFromPipeline = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name
    )

    process {
        $fileSystems = Sync-String "https://images.linuxcontainers.org/streams/v1/index.json" |
        ConvertFrom-Json |
        ForEach-Object { $_.index.images.products } | Select-String 'amd64:default$' |
        ForEach-Object { $_ -replace '^(?<distro>[^:]+):(?<release>[^:]+):.*', '${distro},"${release}"' } |
        ConvertFrom-Csv -Header Os, Release

        if ($Name.Length -gt 0) {
            $fileSystems = $fileSystems | Where-Object {
                foreach ($pattern in $Name) {
                    if ($_.Os -ilike $pattern) {
                        return $true
                    }
                }

                return $false
            }
            if ($null -eq $fileSystems) {
                throw [UnknownWslImageException]::new($Name)
            }
        }

        return $fileSystems
    }
}
