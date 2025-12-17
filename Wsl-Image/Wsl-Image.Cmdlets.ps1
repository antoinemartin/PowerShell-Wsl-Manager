function New-WslImage {
    <#
    .SYNOPSIS
    Creates a WslImage object.

    .DESCRIPTION
    WslImage object retrieve and provide information about available root
    filesystems.

    .PARAMETER Source
    A WslImageSource object representing the image source to create a local image from.

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

    .PARAMETER Uri
    A URI object representing the location of the root filesystem.

    .PARAMETER File
    A FileInfo object of the compressed root filesystem.

    .INPUTS
    WslImageSource[]
    You can pipe WslImageSource objects to this cmdlet.

    .OUTPUTS
    WslImage
    The cmdlet returns WslImage objects that represent the WSL root filesystems.

    .EXAMPLE
    New-WslImage -Name "incus://alpine#3.19"
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
        Incus alpine       3.19                   Synced incus.alpine_3.19.rootfs.tar.gz
    Creates a WSL root filesystem from the incus alpine 3.19 image.

    .EXAMPLE
    New-WslImage -Name "alpine"
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Builtin Alpine       3.19                   Synced alpine.rootfs.tar.gz
    Creates a WSL root filesystem from the builtin Alpine image.

    .EXAMPLE
    New-WslImage -File (Get-Item "C:\temp\test.rootfs.tar.gz")
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Local   Alpine       3.21.3                 Synced test.rootfs.tar.gz
    Creates a WSL root filesystem from a local file.

    .EXAMPLE
    New-WslImage -Name "C:\temp\test.rootfs.tar.gz"
        Type Os           Release                 State Name
        ---- --           -------                 ----- ----
    Local   Alpine       3.21.3                 Synced test.rootfs.tar.gz
    Creates a WSL root filesystem from a local file without requiring a FileInfo object.

    .EXAMPLE
    Get-WslImageSource | New-WslImage
    Creates WslImage objects from all available image sources.

    .LINK
    Get-WslImage
    Get-WslImageSource
    #>
    [Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSUseShouldProcessForStateChangingFunctions', '')]
    [CmdletBinding()]
    [OutputType([WslImage])]
    param (
        [Parameter(Position=0, Mandatory = $true, ParameterSetName = 'Source', ValueFromPipeline = $true)]
        [WslImageSource[]]$Source,
        [Parameter(ParameterSetName = 'Name', ValueFromPipeline = $true, Mandatory = $true)]
        [string]$Name,
        [Parameter(ParameterSetName = 'Uri', ValueFromPipeline = $true, Mandatory = $true)]
        [Uri]$Uri,
        [Parameter(ParameterSetName = 'File', ValueFromPipeline = $true, Mandatory = $true)]
        [FileInfo]$File
    )

    process {
        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Source = New-WslImageSource -Name $Name
        } elseif ($PSCmdlet.ParameterSetName -eq "File") {
            $Source = New-WslImageSource -File $File
        } elseif ($PSCmdlet.ParameterSetName -eq "Uri") {
            $Source = New-WslImageSource -Uri $Uri
        }
        [WslImageDatabase] $imageDb = Get-WslImageDatabase
        $Source | ForEach-Object {
            $imageSource = $_
            if (-not $imageSource.IsCached) {
                $imageSource.Id = [Guid]::NewGuid()
                $imageDb.SaveImageSource($imageSource.ToObject())
            }
            Write-Verbose "Creating local image from source Id $($imageSource.Id)..."
            $imageDb.CreateLocalImageFromImageSource($imageSource.Id) | ForEach-Object {
                $result = [WslImage]::new($_, $imageSource)
                if ($result.RefreshState()) {
                    $imageDb.SaveLocalImage($result.ToObject())
                }
                $result
            }
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
    WslImage[]
    The WslImage Objects to process.

    .OUTPUTS
    WslImage[]
    The WslImage objects.

    .EXAMPLE
    Sync-WslImage -Name "Alpine"
    Syncs the builtin Alpine root filesystem.

    .EXAMPLE
    Sync-WslImage -Name "Alpine" -Force
    Re-download the Alpine builtin root filesystem.

    .EXAMPLE
    Get-WslImage -State NotDownloaded -Os Alpine | Sync-WslImage
    Synchronize the Alpine root filesystems not already synced

    .EXAMPLE
    New-WslImage -Name "alpine" | Sync-WslImage | ForEach-Object { &wsl --import test $env:LOCALAPPDATA\Wsl\test $_.File.FullName }
    Create a WSL distro from a synchronized root filesystem.

    .LINK
    New-WslImage
    Get-WslImage
    #>
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([WslImage])]
    param (
        [Parameter(Position = 0, ParameterSetName = 'Name', ValueFromPipeline = $true, Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [string[]]$Name,
        [Parameter(Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Image")]
        [WslImage[]]$Image,
        [Parameter(Mandatory = $false)]
        [switch]$Force
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Image = $Name | ForEach-Object {
                $existing = Get-WslImage -Name $_
                if ($existing.Count -eq 0) {
                    Write-Verbose "Image '$_' not found locally. Creating new image."
                    $existing = New-WslImage -Name $_
                }
                $existing
            }
        }

        if ($null -ne $Image) {

            If (!([WslImage]::BasePath.Exists)) {  # nocov
                if ($PSCmdlet.ShouldProcess([WslImage]::BasePath.Create(), "Create base path")) {
                    [WslImage]::BasePath.Create()
                }
            }
            [WslImageDatabase] $imageDb = Get-WslImageDatabase
            $Image | ForEach-Object {
                $fs = $_

                if ($true -eq $Force -and $null -ne $fs.Source) {
                    $null = Update-WslImageSource -ImageSource $fs.Source | Save-WslImageSource
                    $fs = Get-WslImage -Id $fs.Id
                }

                # Check if we need to download something
                $oldFile = $null
                $oldFileName = $null
                if ($fs.State -eq [WslImageState]::Outdated) {
                    $oldFileName = $fs.LocalFilename
                    $oldFile = $fs.File

                    Write-Verbose "Image [$($fs.OsName)] is outdated. Old file: [$($oldFileName)]. New file: [$($fs.Source.LocalFilename)]."
                    Write-Verbose "Update metadata from source."
                    $fs.UpdateFromSource()
                }
                [FileInfo] $dest = $fs.File

                if (!$dest.Exists -or $true -eq $Force -or $null -ne $oldFile) {
                    if ($PSCmdlet.ShouldProcess($fs.Url, "Sync locally")) {
                        try {
                            $fs.DownloadAndCheckFile()
                            $fs.State = [WslImageState]::Synced

                            $imageDb.SaveLocalImage($fs.ToObject())
                            # Remove old file if needed
                            if ($null -ne $oldFile -and $oldFileName -ne $fs.LocalFilename) {
                                $existing = $imageDb.GetLocalImages("LocalFilename = @LocalFilename", @{ LocalFilename = $oldFileName })
                                if ($existing.Count -eq 0) {
                                    Write-Verbose "Removing old file [$($oldFile.FullName)]."
                                    try {
                                        $oldFile.Delete()
                                    }
                                    catch { # nocov
                                        Warning "Unable to delete old file [$($oldFile.FullName)]: $($_.Exception.Message)"
                                    }
                                }
                            }

                            Success "[$($fs.OsName)] Synced at [$($dest.FullName)]."
                        }
                        catch [Exception] {
                            throw [WslManagerException]::new("Error while loading distro [$($fs.OsName)] on $($fs.Url): $($_.Exception.Message)", $_.Exception)
                        }
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
        Specifies the name of the filesystem. Supports wildcards.
    .PARAMETER Os
        Specifies the operating system of the filesystem.
    .PARAMETER Type
        Specifies the type of the filesystem source (All, Builtin, Local, Incus, Docker).
    .PARAMETER State
        Specifies the state of the image (NotDownloaded, Synced, Outdated).
    .PARAMETER Configured
        Return only configured builtin images when present, or unconfigured when not present.
    .PARAMETER Outdated
        Return the list of outdated images. Works mainly on Builtin images.
    .PARAMETER Source
        Filters by a specific WslImageSource object.
    .INPUTS
        System.String
        You can pipe image names to this cmdlet.
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
    .EXAMPLE
        Get-WslImage -State NotDownloaded
        Get all images that are not yet downloaded.
    .EXAMPLE
        Get-WslImage -Configured
        Get all configured builtin images.
    .EXAMPLE
        Get-WslImage -Outdated
        Get all outdated images that need updating.
    #>
    [CmdletBinding()]
    [OutputType([WslImage])]
    param(
        [Parameter(Mandatory = $false, Position = 0, ValueFromPipeline = $true, ParameterSetName = 'Name')]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [string]$Os,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [WslImageSourceType]$Type = [WslImageSourceType]::All,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [WslImageState]$State,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [switch]$Configured,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [switch]$Outdated,
        [Parameter(Mandatory = $false, ParameterSetName = 'Name')]
        [WslImageSource]$Source,
        [Parameter(Mandatory = $true, ParameterSetName = 'Id')]
        [Guid[]]$Id
    )

    process {
        $operators = @()
        $parameters = @{}

        $typesInUse = @()

        if ($PSCmdlet.ParameterSetName -eq 'Id') {
            $operators += "Id IN (@Ids)"
            $parameters["Ids"] = $Id | ForEach-Object { $_.ToString() }
        } else {

            if ($Type -ne [WslImageSourceType]::All) {
                foreach ($sourceType in [WslImageSourceType].GetEnumNames()) {
                    if ('All' -eq $sourceType) {
                        continue
                    }
                    if ($Type -band [WslImageSourceType]::$sourceType) {
                        $typesInUse += $sourceType
                    }
                }
            }

            if ($typesInUse.Count -gt 0) {
                $operators += "Type IN (" + (($typesInUse | ForEach-Object { "'$_'" }) -join ", ") + ")"
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

            if ($PSBoundParameters.ContainsKey("Source")) {
                $operators += "ImageSourceId = @ImageSourceId"
                $parameters["ImageSourceId"] = $Source.Id.ToString()
            }

            if ($Name.Length -gt 0) {
                $operators += ($Name | ForEach-Object { "(Name GLOB '$($_)')" }) -join " OR "
            }
        }
        $whereClause = $operators -join " AND "
        Write-Verbose "Get-WslImage: WHERE $whereClause with parameters $($parameters | ConvertTo-Json -Compress)"

        [WslImageDatabase] $imageDb = Get-WslImageDatabase
        $fileSystems = $imageDb.GetLocalImages($whereClause, $parameters)

        # Retrieve related image sources
        $sourceIds = $fileSystems | Where-Object { $null -ne $_.ImageSourceId } | Select-Object -ExpandProperty ImageSourceId -Unique | ForEach-Object { "'$_'" }
        $query = "Id IN ($($sourceIds -join ','))"
        $sources = $imageDb.GetImageSources($query, @{}) | ForEach-Object { [WslImageSource]::new($_) } | Group-Object -Property Id -AsHashTable -AsString
        if ($null -eq $sources) {
            Write-Verbose "No image sources found."
            $sources = @{}
        } # else {
        #     Write-Verbose "Found $($sources.Count) image sources.$($sources.Keys | ForEach-Object { "`n - $_" })"
        #}

        $result = $fileSystems | ForEach-Object {
            if ($null -eq $_.ImageSourceId -or -not $sources.ContainsKey($_.ImageSourceId)) { # nocov
                # Write-Verbose "No image source found for image [$($_.Id)] ($($_.ImageSourceId)). Creating without source."
                [WslImage]::new($_)
            }
            else {
                $imageSources = $sources[$_.ImageSourceId]
                # Write-Verbose "Linking image source [$($_.ImageSourceId)] to image [$($_.Id)]"
                [WslImage]::new($_, $imageSources[0])
            }
        }

        return $result
    }
}


<#
.SYNOPSIS
Remove a WSL root filesystem from the local disk.

.DESCRIPTION
If the WSL root filesystem is synced, it will remove the tar file and its meta
data from the disk. Builtin root filesystems will still appear as output of
`Get-WslImage`, but their state will be `NotDownloaded`.

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

In this case, it will refer to the specified image from
https://images.linuxcontainers.org/images.

Supports wildcards.

.PARAMETER Image
The WslImage object representing the WSL root filesystem to delete.

.INPUTS
WslImage[]
One or more WslImage objects representing the WSL root filesystem to
delete.

.OUTPUTS
WslImage[]
The WslImage objects updated.

.EXAMPLE
Remove-WslImage -Name "alpine"
Removes the alpine root filesystem.

.EXAMPLE
New-WslImage -Name "incus://alpine#3.19" | Remove-WslImage
Removes the Incus alpine 3.19 root filesystem.

.EXAMPLE
Get-WslImage -Type Incus | Remove-WslImage
Removes all the Incus root filesystems present locally.

.EXAMPLE
Remove-WslImage -Name "*alpine*"
Removes all root filesystems with 'alpine' in their name.

.Link
Get-WslImage
New-WslImage
#>
Function Remove-WslImage {
    [CmdletBinding(SupportsShouldProcess = $true)]
    [OutputType([WslImage])]
    param (
        [Parameter(ParameterSetName = 'Name', Mandatory = $true)]
        [ValidateNotNullOrEmpty()]
        [SupportsWildcards()]
        [string[]]$Name,
        [Parameter(Position=0, Mandatory = $true, ValueFromPipeline = $true, ParameterSetName = "Image")]
        [WslImage[]]$Image
    )

    process {

        if ($PSCmdlet.ParameterSetName -eq "Name") {
            $Image = Get-WslImage -Name $Name
        }

        if ($null -ne $Image) {
            $db = Get-WslImageDatabase
            $Image | ForEach-Object {
                $_.Delete() | Out-Null
                $db.RemoveLocalImage($_.Id)
                $_
            }
        }
    }
}
