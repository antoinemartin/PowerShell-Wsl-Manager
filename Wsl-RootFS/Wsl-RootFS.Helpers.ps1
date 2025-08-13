
# We don't support ARM yet
$incus_directory_suffix = "amd64/default"
$incus_rootfs_name = "rootfs.tar.xz"


function Emoji {
    param (
        [string]$code
    )
    $EmojiIcon = [System.Convert]::toInt32($code, 16)
    return [System.Char]::ConvertFromUtf32($EmojiIcon)
}

$script:HourGlass = Emoji "231B"
$script:PartyPopper = Emoji "1F389"
$script:Eyes = Emoji "1F440"

function Progress {
    param (
        [string]$message
    )
    Write-Host "$script:HourGlass " -NoNewline
    Write-Host -ForegroundColor DarkGray $message
}

function Success {
    param (
        [string]$message
    )
    Write-Host "$script:PartyPopper " -NoNewline
    Write-Host -ForegroundColor DarkGreen $message
}

function Information {
    param (
        [string]$message
    )
    Write-Host "$script:Eyes " -NoNewline
    Write-Host -ForegroundColor DarkYellow $message
}

function Get-LxdRootFSUrl {
    <#
    .SYNOPSIS
    Returns the URL of the root filesystem of the Incus image for the specified OS
    and Release.

    .DESCRIPTION
    Incus images made by canonical (https://images.linuxcontainers.org/images) are
    "rolling". In Consequence, getting the current root filesystem URL for a distro
    Involves browsing the distro directory to get the directory name of the last
    build.

    .PARAMETER Os
    Parameter The name of the OS (debian, ubuntu, alpine, rockylinux, centos, ...)

    .PARAMETER Release
    The release (version). Highly dependent on the distro. For rolling release
    distributions (e.g. Arch), use `current`.

    .OUTPUTS
    string
    The URL of the root filesystem for the requested distribution.

    .EXAMPLE
    Get-LxdRootFSUrl almalinux 8
    Returns the URL of the root filesystem for almalinux version 8

    .EXAMPLE
    Get-LxdRootFSUrl -Os centos -Release 9-Stream
    Returns the URL of the root filesystem for CentOS Stream version 9
    #>
    param (
        [Parameter(Position = 0, Mandatory = $true)]
        [string]$Os,
        [Parameter(Position = 1, Mandatory = $true)]
        [string]$Release
    )

    $url = "$base_incus_url/$Os/$Release/$incus_directory_suffix"

    try {
        $last_release_directory = (Invoke-WebRequest $url).Links | Select-Object -Last 1 -ExpandProperty "href"
    }
    catch {
        throw [UnknownIncusDistributionException]::new($OS, $Release)
    }

    return [System.Uri]"$url/$last_release_directory$incus_rootfs_name"
}

# This function is here to mock the download in unit tests
function Sync-File {
    param(
        [System.Uri]$Url,
        [FileInfo]$File
    )
    Progress "Downloading $($Url)..."
    Start-Download $Url $File.FullName
}

# Another function to mock in unit tests
function Sync-String {
    param(
        [Parameter(Position = 0, Mandatory = $true, ValueFromPipeline = $true)]
        [System.Uri]$Url
    )
    process {
        return (New-Object Net.WebClient).DownloadString($Url)
    }
}

function Remove-NullProperties {
    <#
    .SYNOPSIS
        Removes null properties from an object.
    .DESCRIPTION
        This function recursively removes all null properties from a PowerShell object.
    .PARAMETER InputObject
        A PowerShell Object from which to remove null properties.
    .EXAMPLE
        $Object | Remove-NullProperties
    #>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory, Position = 0, ValueFromPipeline)]
        [object]
        $InputObject
    )
    foreach ($object in $InputObject) {
        $objectType = $object.GetType()
        if ($object -is [string] -or $objectType.IsPrimitive -or $objectType.Namespace -eq 'System') {
            $object
            return
        }

        $NewObject = @{ }
        $PropertyList = $object.PSObject.Properties | Where-Object { $null -ne $_.Value }
        foreach ($Property in $PropertyList) {
            $NewObject[$Property.Name] = Remove-NullProperties $Property.Value
        }
        [PSCustomObject]$NewObject
    }
}

function Convert-PSObjectToHashtable {
  [CmdletBinding()]
    param (
        [Parameter(ValueFromPipeline)]
        $InputObject
    )

    process
    {
        if ($null -eq $InputObject) { return $null }

        if ($InputObject -is [System.Collections.IEnumerable] -and $InputObject -isnot [string])
        {
            $collection = @(
                foreach ($object in $InputObject) { Convert-PSObjectToHashtable $object }
            )

            Write-Output -NoEnumerate $collection
        }
        elseif ($InputObject -is [PSObject])
        {
            $hash = @{}

            foreach ($property in $InputObject.PSObject.Properties)
            {
                $hash[$property.Name] = (Convert-PSObjectToHashtable $property.Value).PSObject.BaseObject
            }

            $hash
        }
        else
        {
            $InputObject
        }
    }
}
