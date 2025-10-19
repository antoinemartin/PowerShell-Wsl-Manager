# Takes as a parameter the output file
[CmdletBinding(SupportsShouldProcess = $true)]
param(
    [Parameter(Mandatory = $true)]
    [string]$OutputFile
)

# Some constants
$IncusImageStreamUrl = "https://images.linuxcontainers.org/streams/v1/index.json"
$IncusBaseImageUrl = "https://images.linuxcontainers.org/images"
$IncusDirectorySuffix = "amd64/default"
$IncusRootfsName = "rootfs.tar.xz"
$DigestsFileName = "SHA256SUMS"

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


# Combination of the two preceding functions that return a WslImage
# for all incus instances
function Get-IncusRootFileSystem {
    process {
        Progress "Processing all incus filesystems"
        Invoke-RestMethod $IncusImageStreamUrl |
            ForEach-Object { $_.index.images.products } | Select-String 'amd64:default$' |
            ForEach-Object { $_ -replace '^(?<distro>[^:]+):(?<release>[^:]+):.*', '${distro},"${release}"' } |
            ConvertFrom-Csv -Header Os, Release |
            ForEach-Object {
                Progress "Processing $($_.Os) $($_.Release)"
                $url = "$IncusBaseImageUrl/$($_.Os)/$($_.Release)/$IncusDirectorySuffix"
                $last_release_directory = try {
                    (Invoke-WebRequest $url).Links | Select-Object -Last 1 -ExpandProperty "href"
                }
                catch {
                    "unknown/"
                }
                $Name = (Get-Culture).TextInfo.ToTitleCase($_.Os)
                $Uri = [System.Uri]"$url/$last_release_directory$IncusRootfsName"
                $DigestUri = [System.Uri]::new($Uri, $DigestsFileName).ToString()
                # Read the digest file to get the SHA256 hash
                $DigestContent = Invoke-RestMethod -Uri $DigestUri -ErrorAction SilentlyContinue
                if ($null -ne $DigestContent) {
                    $DigestHash = ($DigestContent | Select-String -Pattern "(\S+)\s+$IncusRootfsName" | ForEach-Object { $_.Matches.Groups[1].Value }).ToUpper()
                } else {
                    $DigestHash = $null
                }

                return [PSCustomObject]@{
                        Type = "Incus"
                        Os = $_.Os
                        Name = $Name
                        Username = 'root'
                        Uid = 0
                        Release = $_.Release
                        Url = $Uri.ToString()
                        Configured = $false
                        LocalFileName = "incus.$($_.Os)_$($_.Release).rootfs.tar.gz"
                        Hash = [PSCustomObject]@{
                            Url       = [System.Uri]::new($Uri, "SHA256SUMS").ToString()
                            Type      = 'sums'
                            Algorithm = 'SHA256'
                        }
                        Digest = $DigestHash
                }
            }
    }
}

Get-IncusRootFileSystem | ConvertTo-Json -Depth 5 | Out-File -FilePath $OutputFile -Encoding utf8 -Force
