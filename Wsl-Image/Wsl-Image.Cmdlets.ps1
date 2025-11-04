
function New-WslImage {
    <#
    .SYNOPSIS
    Creates a WslImage object.

    .DESCRIPTION
    WslImage object retrieve and provide information about available root
    filesystems.

    .PARAMETER Name
    The identifier of the image. It can be an already known name:
    - Arch
    - Alpine
    - Ubuntu
    - Debian

    It also can be the URL (https://...) of an existing filesystem or a
    image name saved through Export-WslInstance.

    It can also be a URL in the form:

        incus://<os>#<release> (ex: incus://rockylinux#9)

    In this case, it will fetch the last version the specified image in
    https://images.linuxcontainers.org/images.

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
    [OutputType([WslImage])]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [string]$Name,
        [Parameter(ParameterSetName = 'Path', ValueFromPipeline = $true, Mandatory = $true)]
        [string]$Path,
        [Parameter(ParameterSetName = 'File', ValueFromPipeline = $true, Mandatory = $true)]
        [FileInfo]$File
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            return [WslImage]::new($Name)
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

    .PARAMETER Name
    The identifier of the image. It can be an already known name:
    - Arch
    - Alpine
    - Ubuntu
    - Debian

    It also can be the URL (https://...) of an existing filesystem or a
    image name saved through Export-WslInstance.

    It can also be a name in the form:

        incus://<os>#<release> (ex: incus://rockylinux#9)

    In this case, it will fetch the last version the specified image in
    https://images.linuxcontainers.org/images.

    It can also designate a docker image in the form:

        docker://<registry>/<image>#<tag> (ex: docker://ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine:latest)

    NOTE: Currently, only images with a single layer are supported.

    .PARAMETER Image
    The WslImage object to process.

    .PARAMETER Force
    Force the synchronization even if the root filesystem is already present locally.

    .INPUTS
    The WslImage Objects to process.

    .OUTPUTS
    The WslImage objects.

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
    [OutputType([WslImage])]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Image")]
        [WslImage[]]$Image,
        [Parameter(Mandatory = $true, ParameterSetName = "Path")]
        [string]$Path,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Image = $Name | ForEach-Object { New-WslImage -Name $_ }
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
                        [WslImage]::BasePath.Create()
                    }
                }

                if (!$dest.Exists -Or $_.Outdated -Or $true -eq $Force) {
                    if ($PSCmdlet.ShouldProcess($fs.Url, "Sync locally")) {
                        try {
                            $fs.DownloadAndCheckFile()
                        }
                        catch [Exception] {
                            throw [WslManagerException]::new("Error while loading distro [$($fs.OsName)] on $($fs.Url): $($_.Exception.Message)", $_.Exception)
                        }
                        $fs.State = [WslImageState]::Synced
                        $fs.WriteMetadata()
                        Success "[$($fs.OsName)] Synced at [$($dest.FullName)]."
                    }
                }
                else {
                    Information "[$($fs.OsName)] Root FS already at [$($dest.FullName)]."
                }

                return $fs
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
        Return the list of outdated images. Works mainly on Builtin images.
    .INPUTS
        System.String
        You can pipe a image name to this cmdlet.
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
    [OutputType([WslImage])]
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
        $operators = @()
        $parameters = @{}
        $sourceOperators = @()
        Update-WslBuiltinImageCache -Type Builtin | Out-Null
        Update-WslBuiltinImageCache -Type Incus | Out-Null
        [WslImageDatabase] $imageDb = Get-WslImageDatabase
        if ($Source -band [WslImageSource]::Local) {
            $sourceOperators += "(ImageSourceId IS NOT NULL)"
        }

        if ($Source -band [WslImageSource]::Builtins) {
            $sourceOperators += "(ImageSourceId IS NULL AND Type = 'Builtin')"
        }
        if ($Source -band [WslImageSource]::Incus) {
            $sourceOperators += "(ImageSourceId IS NULL AND Type = 'Incus')"
        }
        $operators += "(" + ($sourceOperators -join " OR ") + ")"

        if ($PSBoundParameters.ContainsKey("Type")) {
            $operators += "Type = @Type"
            $parameters["Type"] = $Type.ToString()
        }

        if ($PSBoundParameters.ContainsKey("Os")) {
            $operators += "Distribution = @Distribution"
            $parameters["Distribution"] = $Os
        }

        if ($PSBoundParameters.ContainsKey("State") -or $PSBoundParameters.ContainsKey("Outdated")) {
            $operators += "State = @State"
            if ($PSBoundParameters.ContainsKey("State")) {
                $parameters["State"] = $State.ToString()
            }
            else {
                $parameters["State"] = [WslImageState]::Outdated.ToString()
            }
        }

        if ($PSBoundParameters.ContainsKey("Configured")) {
            $operators += "Configured = @Configured"
            $parameters["Configured"] = if ($Configured.IsPresent) { 'TRUE' } else { 'FALSE' }
        }

        if ($Name.Length -gt 0) {
            $operators += ($Name | ForEach-Object { "(Name GLOB '$($_)')" }) -join " OR "
        }
        $whereClause = $operators -join " AND "
        Write-Verbose "Get-WslImage: WHERE $whereClause with parameters $($parameters | ConvertTo-Json -Compress)"
        $fileSystems = $imageDb.GetAllImages($whereClause, $parameters, $true)

        return $fileSystems | ForEach-Object { [WslImage]::new($_) }
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
The identifier of the image. It can be an already known name:
- Arch
- Alpine
- Ubuntu
- Debian

It also can be the URL (https://...) of an existing filesystem or a
image name saved through Export-WslInstance.

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
    [OutputType([WslImage])]
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
            $db = Get-WslImageDatabase
            $Image | ForEach-Object {
                if ($_.Delete()) {
                    $db.RemoveLocalImage($_.Id)
                    $_
                }
            }
        }
    }
}
