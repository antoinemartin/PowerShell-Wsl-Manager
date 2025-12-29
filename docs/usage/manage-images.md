# Manage images

## Introduction

We call images the root filesystem tarballs that are used to create WSL
instances.

Wsl Manager caches these images locally to avoid re-downloading them each time
an image is created. This allows faster instance creation and offline usage.

The actual image files (root filesystems) are located in
`$Env:LOCALAPPDATA\Wsl\RootFS`. Each one is stored as a file with the
`rootfs.tar.gz` suffix and with its digest (SHA256) as a prefix. For instance:

```ps1con
PS> # Get the local filename of the first image
PS> (gwsli | Select-Object -First 1).LocalFilename
EAA1B653F754EC92D893CA4D7CC97EDB8EA08B57CCB41A00973AC80A79AC3AE8.rootfs.tar.gz
```

!!! tip "Filename format"

    Using the digest as a filename ensures that images are not duplicated on disk if
    they are the same (for instance, multiple instances created from the same image
    will share the same root filesystem file).

    Some images may be compressed with other formats than gunzip (e.g. zstd).
    However, the file suffix is still `tar.gz` and WSL will recognize it because
    it uses `bsdtar` under the hood.

The metadata of the images (name, type, os, release, ...) as well as their
source are stored in a local SQLite database located in
`$Env:LOCALAPPDATA\Wsl\RootFS\images.db`.

This information can be queried using the `Get-WslImage` cmdlet (alias `gwsli`).
For instance:

??? example "Get image details"

    ```ps1con
    PS> Get-WslImage alpine | Format-List *

    Id                 : 32031732-dd91-4d42-a715-5d59c0dd5d3d
    SourceId           : fd46c4ca-c183-44bb-ab54-c8d10bf0e833
    Name               : alpine
    State              : Synced
    Type               : Builtin
    CreationDate       : 21/12/2025 19:43:22
    UpdateDate         : 21/12/2025 19:45:32
    Url                : docker://ghcr.io/antoinemartin/powershell-wsl-manager/alpine#latest
    Configured         : True
    Username           : alpine
    Uid                : 1000
    Os                 : Alpine
    Release            : 3.23.2
    LocalFileName      : 0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz
    Size               : 37255108
    DigestUrl          :
    DigestAlgorithm    : SHA256
    DigestType         : docker
    FileHash           : 0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0
    Source             : WslImageSource
    IsLocalOnly        : False
    OsName             : Alpine:3.23.2
    FileName           : 0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz
    File               : C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz
    IsAvailableLocally : True
    Length             : 36,1 MB
    OnlineHash         : 0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0
    Outdated           : False
    IsCached           : True

    PS>
    ```

Each image is associated with a source, which describes where the image comes
from. The sources can be listed with the `Get-WslImageSource` cmdlet:

```ps1con
PS> Get-WslImageSource
Name                 Type Distribution Release      Configured         Length UpdateDate
----                 ---- ------------ -------      ----------         ------ ----------
alpine-base       Builtin Alpine       3.23.2       False              3,5 MB 22/12/2025 11:51:21
alpine            Builtin Alpine       3.23.2       True              35,5 MB 22/12/2025 11:51:21
...
PS>
```

When creating a new WSL instance with `New-WslInstance arch -From arch` for
instance, the image source and the corresponding image are managed automatically
by the module. The following sections are interesting to manage images with the
module. They describe the different types of images available as well as how to
synchronize, update and remove them.

## Types of images

images can currently be of the following types:

### Builtin

Builtin images are images that are officially supported by Wsl Manager. They are
built from official sources and maintained by the Wsl Manager project. They are
stored as docker images in the Github Container Registry under the
`antoinemartin/powershell-wsl-manager` namespace.

These images can be used directly by their name when creating a new WSL
instance. e.g.

```ps1con
PS> New-WslInstance mydebian -From debian
```

They are also the ones returned by the `Get-WslImageSource` command (see above).

The currently available distributions are:

- [Archlinux] (`arch`). As this is a _rolling_ distribution, there is no version
  attached. The current image used as base is 2025-08-01.
- [Alpine] 3.23 (`alpine`)
- [Ubuntu] 26.04 (`ubuntu`)
- [Debian] 13 (`debian`)
- [OpenSuse] tumbleweed (`opensuse-tumbleweed`). This is also a _rolling_
  distribution.

Each of these distributions comes into 2 flavors: Configured (the default) and
Unconfigured by adding the suffix `-base`. The difference between configured and
base images is described in the
[create instances documentation](../create-instances/#configured-vs-base-instances).

The available builtin images can be listed using
`Get-WslImage -Source Builtins`:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> Get-WslImageSource
    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    alpine-base       Builtin Alpine       3.23.2       False              3,5 MB 22/12/2025 11:51:21
    alpine            Builtin Alpine       3.23.2       True              35,5 MB 22/12/2025 11:51:21
    ...

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> Get-WslImageSource
    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    alpine-base       Builtin Alpine       3.23.2       False              3,5 MB 22/12/2025 11:51:21
    alpine            Builtin Alpine       3.23.2       True              35,5 MB 22/12/2025 11:51:21
    arch-base         Builtin Arch         2025.12.01   False            209,3 MB 22/12/2025 11:51:21
    arch              Builtin Arch         2025.12.01   True             375,9 MB 22/12/2025 11:51:21
    debian-base       Builtin Debian       13           False             29,4 MB 22/12/2025 11:51:21
    debian            Builtin Debian       13           True             141,7 MB 22/12/2025 11:51:21
    opensuse-tumb...  Builtin Opensuse-... 20251217     False             46,4 MB 22/12/2025 11:51:21
    opensuse-tumb...  Builtin Opensuse-... 20251217     True             108,6 MB 22/12/2025 11:51:21
    ubuntu-base       Builtin Ubuntu       26.04        False            377,6 MB 22/12/2025 11:51:21
    ubuntu            Builtin Ubuntu       26.04        True             430,8 MB 22/12/2025 11:51:21

    PS>
    ```

Builtin images are refreshed every sunday night by a [github actions workflow].
They are made available in the Github Packages registry (https://ghcr.io) on the
`antoinemartin` namespace. The full list is available [here
:material-open-in-new:][images]{target="\_blank"}.

The list of builtin images are stored in the github repository in an _ad-hoc_
branch called `rootfs`. The actual fetched URL containing the list is:

> https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json

The list is stored locally in the SQLite database
(`$Env:LOCALAPPDATA\Wsl\RootFS\images.db`). It is refreshed if it's older than
one day.

It's possible to force refresh using the `-Sync` switch:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> Get-WslImageSource -Type Builtins -Sync
    ⌛ Fetching Builtins images from: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json

    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    alpine-base       Builtin Alpine       3.23.2       False              3,5 MB 22/12/2025 11:51:21
    ... (ommitted for brevity)...

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> Get-WslImageSource -Type Builtins -Sync
    ⌛ Fetching Builtins images from: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json

    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    alpine-base       Builtin Alpine       3.23.2       False              3,5 MB 22/12/2025 11:51:21
    alpine            Builtin Alpine       3.23.2       True              35,5 MB 22/12/2025 11:51:21
    arch-base         Builtin Arch         2025.12.01   False            209,3 MB 22/12/2025 11:51:21
    arch              Builtin Arch         2025.12.01   True             375,9 MB 22/12/2025 11:51:21
    debian-base       Builtin Debian       13           False             29,4 MB 22/12/2025 11:51:21
    debian            Builtin Debian       13           True             141,7 MB 22/12/2025 11:51:21
    opensuse-tumb...  Builtin Opensuse-... 20251217     False             46,4 MB 22/12/2025 11:51:21
    opensuse-tumb...  Builtin Opensuse-... 20251217     True             108,6 MB 22/12/2025 11:51:21
    ubuntu-base       Builtin Ubuntu       26.04        False            377,6 MB 22/12/2025 11:51:21
    ubuntu            Builtin Ubuntu       26.04        True             430,8 MB 22/12/2025 11:51:21

    PS>
    ```

### Incus

[Incus], formerly known as LXD, is a solution to run Linux system containers on
a Linux machine. It's somewhat like WSL for Linux, but with more features. LXD
was originally developed by Canonical, the company behind Ubuntu, and is now
maintained by the [linux containers project]. The project maintains images as
root filesystems for a fair amount of linux distributions (list
[here](https://images.linuxcontainers.org/)).

The list of available Incus images can be obtained with the command:

```ps1con
PS> Get-WslImage -Source Incus

Name                 Type Distribution Release      Configured         Length UpdateDate
----                 ---- ------------ -------      ----------         ------ ----------
almalinux           Incus Almalinux    10           False             80,0 MB 22/12/2025 11:49:43
...(cut for brevity)...
voidlinux           Incus Voidlinux    current      False             99,4 MB 22/12/2025 11:49:43

PS>
```

A Incus based WSL instance can be created with `Install-Wsl` by passing a image
Url with the following syntax:

    incus://<os>#<release>

for instance:

```bash
PS> New-WslInstance test -From incus://rockylinux#9 | Invoke-WslConfigure | Invoke-WslInstance
...
```

Wsl Manager maintains a list of available Incus images and their metadata. This
list is hosted in the github repository in the special `rootfs` branch, along
with the list of builtin images.

The actual fetched Url is:

> https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json

The list is updated every night at 2am by a Github Actions workflow that fetches
the latest images for Incus and stores their metadata in a format easier to
parse by the module.

The related information is stored locally by Wsl Manager in the SQLite database
(`$Env:LOCALAPPDATA\Wsl\Image\images.db`). It is refreshed if the local copy in
the database is older than a day.

Like the builtin images, the Incus images list can also be forced refreshed with
the `-Sync` switch:

```ps1con
PS> Get-WslImageSource -Type Incus -Sync
⌛ Fetching Incus images from: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
almalinux           Incus almalinux    10           False           NotDownloaded incus.almalinux_10.rootfs.tar.gz
...(cut for brevity)...
voidlinux           Incus voidlinux    current      False           NotDownloaded incus.voidlinux_current.rootf...

PS>
```

### Uri

The `Uri` type of images is for images that have been installed from a URL. Look
at the following example with the official
[archlinux WSL image](https://wiki.archlinux.org/title/Install_Arch_Linux_on_WSL)
that is configured to start systemd on launch:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> New-WslInstance archsystemd -From https://mirror.pkgbuild.com/wsl/latest/archlinux.wsl
    ...
    PS> Get-WslImage archlinux

    Name                 Type Os           Release      Configured              State               Length
    ----                 ---- --           -------      ----------              -----               ------
    archlinux             Uri Archlinux    latest       False                  Synced             131,1 MB

    PS> Get-WslImageSource archlinux -Type Uri

    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    archlinux             Uri Archlinux    latest       False            131,1 MB 23/12/2025 09:48:11

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> New-WslInstance archsystemd -From https://mirror.pkgbuild.com/wsl/latest/archlinux.wsl | Invoke-WslInstance
    ⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\archsystemd]...
    ⌛ Downloading https://mirror.pkgbuild.com/wsl/latest/archlinux.wsl...
    archlinux.wsl (131,1 MB) [=================================================================================================================================================================================================] 100%
    🎉 [Archlinux:latest] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\8DFE92910A188F191B0AF2972BD4BDA661178B769CE820A8921E8B7AEAE9A517.rootfs.tar.gz].
    ⌛ Creating instance [archsystemd] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\8DFE92910A188F191B0AF2972BD4BDA661178B769CE820A8921E8B7AEAE9A517.rootfs.tar.gz]...
    🎉 Done. Command to enter instance: Invoke-WslInstance -In archsystemd or wsl -d archsystemd

    Name                                        State Version Default
    ----                                        ----- ------- -------
    archsystemd                                 Stopped       2   False

    PS> Get-WslImage archlinux

    Name                 Type Os           Release      Configured              State               Length
    ----                 ---- --           -------      ----------              -----               ------
    archlinux             Uri Archlinux    latest       False                  Synced             131,1 MB

    PS> Get-WslImageSource archlinux -Type Uri

    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    archlinux             Uri Archlinux    latest       False            131,1 MB 23/12/2025 09:48:11

    PS>
    ```

### Docker/OCI Images

images can also be downloaded from Docker/OCI compatible registries like GitHub
Container Registry (`ghcr.io`) or the docker hub (`docker.io`). This
functionality is built into the module for accessing container images that
contain images as single layers.

When using Docker URIs with the format `docker://registry/image#tag`, the module
will:

1. Authenticate with the registry
2. Download the image manifest
3. Extract the single layer containing the image
4. Save it as a compressed tar.gz file

This is particularly useful for accessing images built and distributed as
container images.

Here is an example that creates a `test` WSL instance from the `edge` alpine
docker hub image and performs its configuration (with use of aliases):

```ps1con
PS> # Equivalent to New-WslInstance -Name test -From docker://docker.io/alpine#edge | Invoke-WslConfigure | Invoke-WslInstance
PS> nwsl test -From docker://docker.io/alpine#edge | cwsl | iwsl
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test]...
⌛ Retrieving docker image manifest for alpine:edge from registry docker.io...
⌛ Downloading Docker image layer from docker.io/library/alpine:edge...
⌛ Retrieving docker image manifest for library/alpine:edge from registry docker.io...
👀 Root filesystem size: 3,5 MB. Digest sha256:d62bb7eb03b5936dc5a5665fd5a6ede7eab4a6bd0ed965be8c6c3c21e1e53931. Downloading...
sha256:d62bb7eb03b5936dc5a5665fd5a6ede7eab4a6bd0ed965be8c6c3c21e1e53931 (3,5 MB) [=========================================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\D62BB7EB03B5936DC5A5665FD5A6EDE7EAB4A6BD0ED965BE8C6C3C21E1E53931.rootfs.tar.gz.tmp. File size: 3,5 MB
🎉 [alpine:edge] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\D62BB7EB03B5936DC5A5665FD5A6EDE7EAB4A6BD0ED965BE8C6C3C21E1E53931.rootfs.tar.gz].
⌛ Creating instance [test] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\D62BB7EB03B5936DC5A5665FD5A6EDE7EAB4A6BD0ED965BE8C6C3C21E1E53931.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In test or wsl -d test
⌛ Running initialization script [C:\Users\AntoineMartin\Documents\WindowsPowerShell\Modules\Wsl-Manager/configure.sh] on instance [test]...
🎉 Configuration of instance [test] completed successfully.
[powerlevel10k] fetching gitstatusd .. [ok]
❯ cat /etc/os-release
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.22.0_alpha20250108
PRETTY_NAME="Alpine Linux edge"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
❯
```

### Local

A local image is only available locally. It is either the result of an
`Export-WslInstance` command (more information
[here](manage-instances.md#export-instance)) or an image that has been created
from a local root filesystem tarball.

## Get images

The list of local images is given by the `Get-WslImage` (alias `gwsli`) command:

```ps1con
PS> Get-WslImage


Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
opensuse           Docker Opensuse-... 20250813     True                   Synced             107,3 MB
docker              Local arch         3.22.1       True                   Synced             511,9 MB
iknite              Local Alpine       3.21.3       False                Outdated             805,1 MB
kaweezle            Local Alpine       3.21.3       False                  Synced             802,2 MB
opensuse              Uri opensuse     unknown      False                  Synced              46,3 MB
python              Local debian       13           True                   Synced             113,7 MB
opensuse              Uri Opensuse     15.6         False                  Synced              39,9 MB
alpine            Builtin Alpine       3.23.2       True                   Synced              36,1 MB
opensuse-tumb...  Builtin Opensuse-... 20251217     False                Outdated              72,3 MB
yawsldocker-a...   Docker Alpine       3.22.1       True                   Synced             148,5 MB
jekyll              Local Alpine       3.22.1       False                  Synced             159,0 MB
archlinux             Uri Archlinux    latest       False                  Synced             131,1 MB
alpine             Docker alpine       edge         False                  Synced               3,5 MB

PS>
```

Several filters are available (see [reference](reference/get-wsl-image.md)),
like:

```ps1con
PS> gwsli -Distribution Alpine

Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
iknite              Local Alpine       3.21.3       False                Outdated             805,1 MB
kaweezle            Local Alpine       3.21.3       False                  Synced             802,2 MB
alpine            Builtin Alpine       3.23.2       True                   Synced              36,1 MB
yawsldocker-a...   Docker Alpine       3.22.1       True                   Synced             148,5 MB
jekyll              Local Alpine       3.22.1       False                  Synced             159,0 MB

PS>
```

You can also get only outdated images with the `-Outdated` switch:

```ps1con
PS> Get-WslImage -Outdated

Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
iknite              Local Alpine       3.21.3       False                Outdated             805,1 MB
opensuse-tumb...  Builtin Opensuse-... 20251217     False                Outdated              72,3 MB

PS>
```

Local images are marked as `Outdated` when the related source image has been
updated and the digest of the local image is no longer the same as the source
image.

An image source can be updated with the `Update-WslImageSource` cmdlet (see
[here](reference/update-wsl-image-source.md)) in order to refresh the status of
local images and mark them as outdated if necessary. Builtin and Incus image
sources are automatically updated if they are older than 1 day when calling
`Get-WslImageSource`, so you usually don't need to do this manually unless you
want to force refresh of the image sources before checking for outdated images.

## Synchronize images

### Fetch builtins images

Local Synchronization of images is performed with the `Sync-WslImage` (`swlsi`
alias) cmdlet. For instance, to fetch the builtin debian base image:

```ps1con
PS> Sync-WslImage debian-base
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/debian-base:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/debian-base:latest from registry ghcr.io...
👀 Root filesystem size: 48,1 MB. Digest sha256:af4880b366245a9a2d4a3dee7341a8073e27ad065dc0deb73357c394f06b62cf. Downloading...
sha256:af4880b366245a9a2d4a3dee7341a8073e27ad065dc0deb73357c394f06b62cf (48,1 MB) [========================================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B5A034812F22D96C746D6CD49E50053F328D9D135B3226A7613DA5F448018000.rootfs.tar.gz.tmp. File size: 48,1 MB
🎉 [Debian:13] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B5A034812F22D96C746D6CD49E50053F328D9D135B3226A7613DA5F448018000.rootfs.tar.gz].

Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
debian-base       Builtin Debian       13           False                  Synced              48,1 MB

PS>
```

### Import local root file systems

You can also synchronize a image from a local file path:

```ps1con
PS> Sync-WslImage -Path "C:\path\to\custom.rootfs.tar.gz"
```

When synchronizing a local image, the cmdlet will attempt to extract linux
distribution information from the root filesystem in order to display the image
metadata correctly. It will look for standard files like `/etc/os-release`,
`/etc/wsl.conf` and `/etc/passwd`, etc.

### Force synchronization

You can force the re-synchronization with the `-Force` switch. For instance, to
force re-synchronization of the builtin Alpine images:

```ps1con
PS> Get-WslImage -Type Builtin -Distribution Alpine | Sync-WslImage -Force
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine:latest from registry ghcr.io...
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine:latest from registry ghcr.io...
👀 Root filesystem size: 36,1 MB. Digest sha256:a8c002573f4fbc85bd96b5b3d30e7cd7c73ae78eccf18d9f00977748d78f82fd. Downloading...
sha256:a8c002573f4fbc85bd96b5b3d30e7cd7c73ae78eccf18d9f00977748d78f82fd (36,1 MB) [========================================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\A8C002573F4FBC85BD96B5B3D30E7CD7C73AE78ECCF18D9F00977748D78F82FD.rootfs.tar.gz.tmp. File size: 36,1 MB
🎉 [Alpine:3.23.2] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\A8C002573F4FBC85BD96B5B3D30E7CD7C73AE78ECCF18D9F00977748D78F82FD.rootfs.tar.gz].

Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
alpine            Builtin Alpine       3.23.2       True                   Synced              36,1 MB

PS>
```

### Update outdated

#### Builtin images

Builtin images can be easily updated when they are outdated:

```ps1con
PS>  Get-WslImage -Outdated -Type Builtin | Sync-WslImage
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine:latest from registry ghcr.io...
👀 Root filesystem size: 36,1 MB. Digest sha256:bdafbeb2ef3f5c150d00351c53c51e2a974758e7d24a6fbbab982632929c531e. Downloading...
sha256:bdafbeb2ef3f5c150d00351c53c51e2a974758e7d24a6fbbab982632929c531e (36,1 MB) [========================================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\BDAFBEB2EF3F5C150D00351C53C51E2A974758E7D24A6FBBAB982632929C531E.rootfs.tar.gz.tmp. File size: 36,1 MB
🎉 [Alpine:3.23.2] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\BDAFBEB2EF3F5C150D00351C53C51E2A974758E7D24A6FBBAB982632929C531E.rootfs.tar.gz].

Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
alpine            Builtin Alpine       3.23.2       True                   Synced              36,1 MB
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/debian-base:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/debian-base:latest from registry ghcr.io...
👀 Root filesystem size: 48,1 MB. Digest sha256:af4880b366245a9a2d4a3dee7341a8073e27ad065dc0deb73357c394f06b62cf. Downloading...
sha256:af4880b366245a9a2d4a3dee7341a8073e27ad065dc0deb73357c394f06b62cf (48,1 MB) [========================================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\AF4880B366245A9A2D4A3DEE7341A8073E27AD065DC0DEB73357C394F06B62CF.rootfs.tar.gz.tmp. File size: 48,1 MB
🎉 [Debian:13] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\AF4880B366245A9A2D4A3DEE7341A8073E27AD065DC0DEB73357C394F06B62CF.rootfs.tar.gz].
debian-base       Builtin Debian       13           False                  Synced              48,1 MB

PS>
```

#### Incus images

The incus images outdated status is also updated automatically when
synchronizing image sources.

#### Other image types

For other types of images (Uri, Docker, Local), you need to manually check for
updates and re-synchronize them as there is no automatic update mechanism for
these types of images. This can done with the following command that will update
all image sources of type Uri, Docker and Local:

```ps1con
PS>  Get-WslImageSource -Source Uri,Docker,Local | Update-WslImageSource
⌛ Retrieving docker image manifest for antoinemartin/yawsldocker/yawsldocker-alpine:latest from registry ghcr.io...

Name                 Type Distribution Release      Configured         Length UpdateDate
----                 ---- ------------ -------      ----------         ------ ----------
yawsldocker-a...   Docker Alpine       3.22.1       True             148,5 MB 23/12/2025 18:56:56
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/opensuse:latest from registry ghcr.io...
opensuse           Docker Opensuse-... 20250813     True             107,3 MB 23/12/2025 18:56:57
⌛ Retrieving docker image manifest for alpine:edge from registry docker.io...
alpine             Docker alpine       edge         False              3,5 MB 23/12/2025 18:56:58
kaweezle            Local Alpine       3.21.3       False            802,2 MB 23/12/2025 18:56:58
jekyll              Local Alpine       3.22.1       True             159,0 MB 23/12/2025 18:56:59
AVERTISSEMENT : The WslImageSource docker (Id: b8a5d1fa-f6e4-45a2-9185-edebab2cc20f) does not have a URL to update from.
docker              Local arch         3.22.1       True                  0 B 16/10/2025 15:42:09
AVERTISSEMENT : The WslImageSource python (Id: cb760bea-4118-423a-89c2-c06e5c5ebd7b) does not have a URL to update from.
python              Local debian       13           True                  0 B 16/10/2025 15:42:09
archlinux             Uri Archlinux    latest       False            131,1 MB 23/12/2025 18:56:59
AVERTISSEMENT : Failed to update WslImageSource from URL https://images.linuxcontainers.org/images/opensuse/15.6/amd64/default/20251109_04:20/rootfs.tar.xz: The specified URL was not found:
https://images.linuxcontainers.org/images/opensuse/15.6/amd64/default/20251109_04%3A20/rootfs.tar.xz
opensuse              Uri Opensuse     15.6         False             39,9 MB 10/11/2025 14:30:46
opensuse              Uri Opensuse     tumbleweed   False             46,4 MB 23/12/2025 18:57:00

PS>
```

You can then re-synchronize the outdated images as shown previously:

```ps1con
PS> Get-WslImage -Outdated -Type Uri,Local,Docker | Sync-WslImage
⌛ Downloading file:///C:/Users/AntoineMartin/AppData/Local/Wsl/RootFS - Copie/kaweezle.rootfs.tar.gz...
kaweezle.rootfs.tar.gz (802,2 MB) [===============================================================================] 100%
🎉 [Alpine:3.21.3] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B6B41F0CECFAD9CE2ECACE59A7336EF0DA9005BF4518BA4D7BBC05B38A6B5AD9.rootfs.tar.gz].

Name                 Type Os           Release      Configured              State               Length
----                 ---- --           -------      ----------              -----               ------
iknite              Local Alpine       3.21.3       False                  Synced             802,2 MB
⌛ Downloading https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz...
opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz (46,4 MB) [===================================================] 100%
🎉 [opensuse:tumbleweed] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\1040342FFDB679BA1FDA75A81611DFCBA61129E1048901FE62F0C3271873E007.rootfs.tar.gz].
opensuse              Uri opensuse     tumbleweed   False                  Synced              46,4 MB

PS>
```

## Remove images

You can remove local images with the `Remove-WslImage` (`rmwsli` alias) cmdlet:

```bash
PS> Remove-WslImage -Distribution opensuse

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
 Builtin Opensuse     tumbleweed      NotDownloaded opensuse.rootfs.tar.gz
```

It can accept image(s) through the pipe:

/// collapse-code

```ps1con
PS> # Get installed images
PS> Get-WslImage -Distribution Opensuse-Tumbleweed

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
opensuse-tumb...  Builtin Opensuse-... 20250820     True                   Synced docker.opensuse-tumbleweed.ro...
opensuse-tumb...  Builtin Opensuse-... 20250820     False                  Synced docker.opensuse-tumbleweed-ba...

PS> # Remove them at once
PS> Get-WslImage -Distribution Opensuse-Tumbleweed | Remove-WslImage

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
opensuse-tumb...  Builtin Opensuse-... 20250820     True            NotDownloaded docker.opensuse-tumbleweed.ro...
opensuse-tumb...  Builtin Opensuse-... 20250820     False           NotDownloaded docker.opensuse-tumbleweed-ba...

PS> # No more local images
PS> Get-WslImage -Distribution Opensuse-Tumbleweed
PS> # Builtins still there
PS> Get-WslImage -Source Builtins -Distribution opensuse-tumbleweed

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
opensuse-tumb...  Builtin Opensuse-... 20250820     True            NotDownloaded docker.opensuse-tumbleweed.ro...
opensuse-tumb...  Builtin Opensuse-... 20250820     False           NotDownloaded docker.opensuse-tumbleweed-ba...

PS>
```

///

## Get images by size

You can order the present filesystem by size with the command:

```bash
PS> Get-WslImage | Sort-Object -Property Length -Descending | Format-Table Name,Type, Os, Release, Configured, @{Label="Size (MB)"; Expression={ [int]($_.Length/1Mb) }}

Name                  Type Os                  Release    Configured Size (MB)
----                  ---- --                  -------    ---------- ---------
iknite               Local Alpine              3.21.3          False       805
kaweezle             Local Alpine              3.21.3          False       802
ubuntu             Builtin Ubuntu              25.10            True       423
arch               Builtin Arch                2025.08.01       True       392
arch-base          Builtin Arch                2025.08.01      False       210
jekyll               Local alpine              3.22.1           True       158
yawsldocker-alpine     Uri Alpine              3.22.1           True       148
opensuse               Uri Opensuse-Tumbleweed 20250813         True       107
opensuse-base          Uri Opensuse-Tumbleweed 20250813        False        71
debian-base        Builtin Debian              13              False        48
alpine             Builtin Alpine              3.22.1           True        35
alpine-base        Builtin Alpine              3.22.1          False         4

PS>
```

<!-- prettier-ignore-start -->
[archlinux]: https://archlinux.org/
[alpine]: https://www.alpinelinux.org/
[ubuntu]: https://ubuntu.org
[debian]: https://debian.org
[opensuse]: https://www.opensuse.org
[github actions workflow]: https://github.com/antoinemartin/PowerShell-Wsl-Manager/blob/main/.github/workflows/
[linux containers project]: https://linuxcontainers.org/
[incus]: https://linuxcontainers.org/incus/introduction/
[images]: https://github.com/antoinemartin?tab=packages&repo_name=PowerShell-Wsl-Manager
<!-- prettier-ignore-end -->
