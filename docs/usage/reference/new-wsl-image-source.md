# New-WslImageSource

```text

NAME
    New-WslImageSource

SYNOPSIS
    Creates a new WSL image source from various input types.


SYNTAX
    New-WslImageSource [-Name] <String> [-Sync] [<CommonParameters>]

    New-WslImageSource -File <FileInfo> [-Sync] [<CommonParameters>]

    New-WslImageSource -Uri <Uri> [-Sync] [<CommonParameters>]


DESCRIPTION
    Creates a WslImageSource object from a name, file path, or URI. The function automatically detects the input type and retrieves distribution information accordingly. It can handle local files, URLs, Docker images, and built-in distributions.


PARAMETERS
    -Name <String>
        Specifies the name, file path, or URI of the WSL image source. The function will attempt to determine the type automatically.

    -File <FileInfo>
        Specifies a FileInfo object representing a local WSL image file (typically a .tar.gz or .wsl file).

    -Uri <Uri>
        Specifies a URI pointing to a WSL image. Supports http, https, docker, file, local, builtin, and incus schemes.

    -Sync [<SwitchParameter>]
        Forces synchronization with remote sources to get the latest information, even if cached data exists.

    <CommonParameters>
        This cmdlet supports the common parameters: Verbose, Debug,
        ErrorAction, ErrorVariable, WarningAction, WarningVariable,
        OutBuffer, PipelineVariable, and OutVariable. For more information, see
        about_CommonParameters (https://go.microsoft.com/fwlink/?LinkID=113216).

    -------------------------- EXAMPLE 1 --------------------------

    PS > New-WslImageSource -Name "ubuntu-22.04-rootfs.tar.gz"

    Creates a WSL image source from a local file name.




    -------------------------- EXAMPLE 2 --------------------------

    PS > New-WslImageSource -Name "https://cloud-images.ubuntu.com/wsl/jammy/current/ubuntu-jammy-wsl-amd64-wsl.rootfs.tar.gz"

    Creates a WSL image source from a URL.




    -------------------------- EXAMPLE 3 --------------------------

    PS > Get-Item "C:\WSL\ubuntu.tar.gz" | New-WslImageSource

    Creates a WSL image source from a file object passed through the pipeline.




    -------------------------- EXAMPLE 4 --------------------------

    PS > New-WslImageSource -Uri "docker://ghcr.io/antoinemartin/powershell-wsl-manager/ubuntu#22.04"

    Creates a WSL image source from a Docker image URI.




    -------------------------- EXAMPLE 5 --------------------------

    PS > New-WslImageSource -Name "ubuntu" -Sync

    Creates a WSL image source for Ubuntu and forces synchronization with remote sources.




REMARKS
    To see the examples, type: "Get-Help New-WslImageSource -Examples"
    For more information, type: "Get-Help New-WslImageSource -Detailed"
    For technical information, type: "Get-Help New-WslImageSource -Full"
    For online help, type: "Get-Help New-WslImageSource -Online"


```
