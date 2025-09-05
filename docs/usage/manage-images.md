# Manage images

## Introduction

The images are located in `$Env:LOCALAPPDATA\Wsl\Image`. Each root file system
is stored as a file with the `rootfs.tar.gz` suffix.

!!! warning

    Some images may be compressed with other formats than gunzip.
    However, the file suffix is still `tar.gz` and WSL will recognize it because
    it uses `bsdtar` under the hood.

Along with each image file, there is a json file containing metadata information
for the image. this file ends with the `rootfs.tar.gz.json` suffix.

## Types of images

images can currently be of the following types:

### Builtin

These are the filesystems that can be used by their name. Currently there is:

- [Archlinux] (`arch`). As this is a _rolling_ distribution, there is no version
  attached. The current image used as base is 2025-08-01.
- [Alpine] 3.22 (`alpine`)
- [Ubuntu] 25.10 (`ubuntu`)
- [Debian] 13 (`debian`)
- [OpenSuse] tumbleweed (`opensuse`). This is also a _rolling_ distribution.

Each of these images comes into 2 flavors: Configured (the default) and
Unconfigured by adding the suffix `-base`.

The available builtin images can be listed using
`Get-WslImage -Source Builtins`:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> Get-WslImage -Source Builtins

    Name                 Type Os           Release      Configured              State FileName
    ----                 ---- --           -------      ----------              ----- --------
    alpine            Builtin Alpine       3.22.1       True            NotDownloaded docker.alpine.rootfs.tar.gz
    alpine-base       Builtin Alpine       3.22.1       False           NotDownloaded docker.alpine-base.rootfs.tar.gz
    ...

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> Get-WslImage -Source Builtins

    Name                 Type Os           Release      Configured              State FileName
    ----                 ---- --           -------      ----------              ----- --------
    alpine            Builtin Alpine       3.22.1       True            NotDownloaded docker.alpine.rootfs.tar.gz
    alpine-base       Builtin Alpine       3.22.1       False           NotDownloaded docker.alpine-base.rootfs.tar.gz
    arch              Builtin Arch         2025.08.01   True            NotDownloaded docker.arch.rootfs.tar.gz
    arch-base         Builtin Arch         2025.08.01   False           NotDownloaded docker.arch-base.rootfs.tar.gz
    debian            Builtin Debian       13           True            NotDownloaded docker.debian.rootfs.tar.gz
    debian-base       Builtin Debian       13           False           NotDownloaded docker.debian-base.rootfs.tar.gz
    opensuse-tumb...  Builtin Opensuse-... 20250817     True            NotDownloaded docker.opensuse-tumbleweed.ro...
    opensuse-tumb...  Builtin Opensuse-... 20250817     False           NotDownloaded docker.opensuse-tumbleweed-ba...
    ubuntu            Builtin Ubuntu       25.10        True            NotDownloaded docker.ubuntu.rootfs.tar.gz
    ubuntu-base       Builtin Ubuntu       25.10        False           NotDownloaded docker.ubuntu-base.rootfs.tar.gz

    PS>
    ```

Builtin images are refreshed every sunday night by a [github actions workflow].
They are made available in the Github Packages registry (https://ghcr.io) on the
`antoinemartin` namespace. The full list is available [here
:material-open-in-new:][images]{target="\_blank"}.

The list of builtin images are stored in the github repository in an _ad-hoc_
branch called `rootfs`. The actual fetched URL containing the list is:

> https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json

The list is stored locally in `$Env:LOCALAPPDATA\Wsl\Image\builtins.rootfs.json`
and refreshed if it's older than one day.

It's possible to force refresh it with the following command:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> Get-WslBuiltinImage -Type Builtins -Sync
    ⌛ Fetching Builtins images from: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json

    Name                 Type Os           Release      Configured              State FileName
    ----                 ---- --           -------      ----------              ----- --------
    debian-base       Builtin Debian       13           False           NotDownloaded docker.debian-base.rootfs.tar.gz
    ... (ommitted for brevity)...

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> Get-WslBuiltinImage -Type Builtins -Sync
    ⌛ Fetching Builtins images from: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json

    Name                 Type Os           Release      Configured              State FileName
    ----                 ---- --           -------      ----------              ----- --------
    debian-base       Builtin Debian       13           False           NotDownloaded docker.debian-base.rootfs.tar.gz
    debian            Builtin Debian       13           True            NotDownloaded docker.debian.rootfs.tar.gz
    ubuntu-base       Builtin Ubuntu       25.10        False           NotDownloaded docker.ubuntu-base.rootfs.tar.gz
    ubuntu            Builtin Ubuntu       25.10        True                   Synced docker.ubuntu.rootfs.tar.gz
    arch-base         Builtin Arch         2025.08.01   False                  Synced docker.arch-base.rootfs.tar.gz
    arch              Builtin Arch         2025.08.01   True                   Synced docker.arch.rootfs.tar.gz
    opensuse-tumb...  Builtin Opensuse-... 20250820     False           NotDownloaded docker.opensuse-tumbleweed-ba...
    opensuse-tumb...  Builtin Opensuse-... 20250820     True            NotDownloaded docker.opensuse-tumbleweed.ro...
    alpine-base       Builtin Alpine       3.22.1       False                  Synced docker.alpine-base.rootfs.tar.gz
    alpine            Builtin Alpine       3.22.1       True                   Synced docker.alpine.rootfs.tar.gz

    PS>
    ```

### Incus

[Incus], or linux containers, is a solution to run Linux system containers on a
Linux machine. It's somewhat like WSL for Linux, but with more features.
Canonical maintains images and images for a fair amount of linux distributions
(list [here](https://jenkins.linuxcontainers.org/view/Images/)).

The list of available Incus images can be obtained with the command:

```ps1con
PS> Get-WslImage -Source Incus

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
almalinux           Incus almalinux    10           False           NotDownloaded incus.almalinux_10.rootfs.tar.gz
...(cut for brevity)...
voidlinux           Incus voidlinux    current      False           NotDownloaded incus.voidlinux_current.rootf...

PS>
```

A Incus based WSL instance can be created with `Install-Wsl` by passing a image
Url with the following syntax:

    incus://<os>#<release>

for instance:

```bash
PS> New-WslInstance test -From incus://rockylinux#9 -SkipConfigure
...
```

Wsl Manager maintains a list of available Incus images and their metadata. This
list is hosted in the github repository in the special `rootfs` branch, along
with the list of builtin images.

The actual fetched Url is:

> https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json

The list is updated every night at 2am.

It is stored locally by Wsl Manager in
`$Env:LOCALAPPDATA\Wsl\Image\builtins.rootfs.json` and refreshed if the local
version is older than a day.

Like the builtin images, the Incus images list can also be forced refreshed with
the following command:

```ps1con
PS> Get-WslBuiltinImage -Type Incus -Sync
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
at the following example with [openwrt](https://openwrt.org/):

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> New-WslInstance openwrt -From https://archive.openwrt.org/releases/24.10.1/targets/x86/64/openwrt-24.10.1-x86-64-rootfs.tar.gz
    ...
    PS> Get-WslImage -Name openwrt*

    Name                 Type Os           Release      Configured              State FileName
    ----                 ---- --           -------      ----------              ----- --------
    openwrt-24.10...      Uri openwrt      unknown      False                  Synced openwrt-24.10.1-x86-64-rootfs...

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> New-WslInstance openwrt -From https://archive.openwrt.org/releases/24.10.1/targets/x86/64/openwrt-24.10.1-x86-64-rootfs.tar.gz
    ⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\openwrt]...
    ⌛ Downloading https://archive.openwrt.org/releases/24.10.1/targets/x86/64/openwrt-24.10.1-x86-64-rootfs.tar.gz...
    openwrt-24.10.1-x86-64-rootfs.tar.gz (4,4 MB) [===================================================================================] 100%
    🎉 [openwrt:unknown] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\openwrt-24.10.1-x86-64-rootfs.tar.gz].
    ⌛ Creating instance [openwrt] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\openwrt-24.10.1-x86-64-rootfs.tar.gz]...
    🎉 Done. Command to enter instance: Invoke-WslInstance -In openwrt or wsl -d openwrt

    Name                                        State Version Default
    ----                                        ----- ------- -------
    openwrt                                   Stopped       2   False

    PS> Get-WslImage -Name openwrt*

    Name                 Type Os           Release      Configured              State FileName
    ----                 ---- --           -------      ----------              ----- --------
    openwrt-24.10...      Uri openwrt      unknown      False                  Synced openwrt-24.10.1-x86-64-rootfs...

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
👀 Failed to get image labels from docker://docker.io/alpine#edge. Using defaults: alpine edge
⌛ Downloading Docker image layer from docker.io/library/alpine:edge...
⌛ Retrieving docker image manifest for library/alpine:edge from registry docker.io...
👀 Root filesystem size: 3,5 MB. Digest sha256:d62bb7eb03b5936dc5a5665fd5a6ede7eab4a6bd0ed965be8c6c3c21e1e53931. Downloading...
sha256:d62bb7eb03b5936dc5a5665fd5a6ede7eab4a6bd0ed965be8c6c3c21e1e53931 (3,5 MB) [============================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz.tmp. File size: 3,5 MB
🎉 [alpine:edge] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz].
⌛ Creating instance [test] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In test or wsl -d test
⌛ Running initialization script [C:\Users\AntoineMartin\Documents\WindowsPowerShell\Modules\Wsl-Manager/configure.sh] on instance [test.Name]...
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

A local image is only available locally. It is the result of an
`Export-WslInstance` command (more information
[here](manage-instances.md#export-instance)).

## Get images

The list of local images is given by the `Get-WslImage` (alias `gwsli`) command:

```ps1con
PS> Get-WslImage

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
alpine                Uri alpine       edge         False                  Synced docker.alpine.rootfs.tar.gz
alpine-base       Builtin Alpine       3.22.1       False                  Synced docker.alpine-base.rootfs.tar.gz
arch              Builtin Arch         2025.08.01   True                   Synced docker.arch.rootfs.tar.gz
arch-base         Builtin Arch         2025.08.01   False                  Synced docker.arch-base.rootfs.tar.gz
opensuse              Uri Opensuse-... 20250813     True                   Synced docker.opensuse.rootfs.tar.gz
opensuse-base         Uri Opensuse-... 20250813     False                  Synced docker.opensuse-base.rootfs.t...
ubuntu            Builtin Ubuntu       25.10        True                   Synced docker.ubuntu.rootfs.tar.gz
yawsldocker-a...      Uri Alpine       3.22.1       True                   Synced docker.yawsldocker-alpine.roo...
iknite              Local Alpine       3.21.3       False                  Synced iknite.rootfs.tar.gz
jekyll              Local alpine       3.22.1       True                   Synced jekyll.rootfs.tar.gz
kaweezle            Local Alpine       3.21.3       False                  Synced kaweezle.rootfs.tar.gz

PS>
```

Several filters are available (see [reference](reference/get-wsl-image.md)),
like:

```ps1con
PS> gwsli -Os ubuntu

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
ubuntu            Builtin Ubuntu       25.10        True                   Synced docker.ubuntu.rootfs.tar.gz

PS>
```

You can also get only outdated images (mainly for Builtin images):

```ps1con
PS> Get-WslImage -Outdated
⌛ Retrieving docker image manifest for alpine:edge from registry docker.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine-base:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/arch:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/arch-base:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/opensuse:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/opensuse-base:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/ubuntu:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/yawsldocker/yawsldocker-alpine:latest from registry ghcr.io...

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
ubuntu            Builtin Ubuntu       25.10        True                   Synced docker.ubuntu.rootfs.tar.gz

PS>
```

## Synchronize images

### Fetch builtins images

Local Synchronization of images is performed with the `Sync-WslImage` (`swlsi`
alias) cmdlet. For instance, to fetch the builtin debian base image:

```ps1con
PS> Sync-WslImage debian-base
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/debian-base:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/debian-base:latest from registry ghcr.io...
👀 Root filesystem size: 48,1 MB. Digest sha256:95f4339cae932f651700847a0b3b12a93488ca3c8d69b658cb2a8c2a9e9469c9. Downloading...
sha256:95f4339cae932f651700847a0b3b12a93488ca3c8d69b658cb2a8c2a9e9469c9 (48,1 MB) [===========================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.debian-base.rootfs.tar.gz.tmp. File size: 48,1 MB
🎉 [Debian:13] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.debian-base.rootfs.tar.gz].

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
debian-base       Builtin Debian       13           False                  Synced docker.debian-base.rootfs.tar.gz

PS>
```

### Import local root file systems

You can also synchronize a image from a local file path:

```ps1con
PS> Sync-WslImage -Path "C:\path\to\custom.rootfs.tar.gz"
```

When synchronizing a local image, the cmdlet will attempt to extract linux
distribution information from the `/etc/os-release` file in order to display the
image details correctly.

### Force synchronization

You can force the re-synchronization with the `-Force` switch. For instance, to
force re-synchronization of the builtin Alpine images:

```ps1con
PS> Get-WslImage -Source Builtins -Os alpine | Sync-WslImage -Force
 Get-WslImage -Source Builtins -Os alpine | Sync-WslImage -Force
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine:latest from registry ghcr.io...
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine:latest from registry ghcr.io...
👀 Root filesystem size: 35,4 MB. Digest sha256:9341cce18da7bfef951bb93e6907f2a08430e7d984990522e83f8bd4706a76df. Downloading...
sha256:9341cce18da7bfef951bb93e6907f2a08430e7d984990522e83f8bd4706a76df (35,4 MB) [===========================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz.tmp. File size: 35,4 MB
🎉 [Alpine:3.22.1] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz].

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
alpine            Builtin Alpine       3.22.1       True                   Synced docker.alpine.rootfs.tar.gz
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine-base:latest from registry ghcr.io...
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine-base:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine-base:latest from registry ghcr.io...
👀 Root filesystem size: 3,6 MB. Digest sha256:9824c27679d3b27c5e1cb00a73adb6f4f8d556994111c12db3c5d61a0c843df8. Downloading...
sha256:9824c27679d3b27c5e1cb00a73adb6f4f8d556994111c12db3c5d61a0c843df8 (3,6 MB) [============================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine-base.rootfs.tar.gz.tmp. File size: 3,6 MB
🎉 [Alpine:3.22.1] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine-base.rootfs.tar.gz].
alpine-base       Builtin Alpine       3.22.1       False                  Synced docker.alpine-base.rootfs.tar.gz

PS>
```

### Update outdated

```ps1con
PS> Get-WslImage -Outdated | Sync-WslImage
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine-base:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/arch:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/arch-base:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/debian-base:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/opensuse:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/opensuse-base:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/ubuntu:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/yawsldocker/yawsldocker-alpine:latest from registry ghcr.io...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/ubuntu:latest from registry ghcr.io...
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/ubuntu:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/ubuntu:latest from registry ghcr.io...
👀 Root filesystem size: 423,1 MB. Digest sha256:a40e0be5f809d815950795bd9039e4111bc0dd69cd8b1f87f1204a0054792cc8. Downloading...
sha256:a40e0be5f809d815950795bd9039e4111bc0dd69cd8b1f87f1204a0054792cc8 (423,1 MB) [==========================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.ubuntu.rootfs.tar.gz.tmp. File size: 423,1 MB
🎉 [Ubuntu:25.10] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.ubuntu.rootfs.tar.gz].

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
ubuntu            Builtin Ubuntu       25.10        True                   Synced docker.ubuntu.rootfs.tar.gz

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

```ps1con
PS> # Get installed images
PS> Get-WslImage -Os Opensuse-Tumbleweed

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
opensuse-tumb...  Builtin Opensuse-... 20250820     True                   Synced docker.opensuse-tumbleweed.ro...
opensuse-tumb...  Builtin Opensuse-... 20250820     False                  Synced docker.opensuse-tumbleweed-ba...

PS> # Remove them at once
PS> Get-WslImage -Os Opensuse-Tumbleweed | Remove-WslImage

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
opensuse-tumb...  Builtin Opensuse-... 20250820     True            NotDownloaded docker.opensuse-tumbleweed.ro...
opensuse-tumb...  Builtin Opensuse-... 20250820     False           NotDownloaded docker.opensuse-tumbleweed-ba...

PS> # No more local images
PS> Get-WslImage -Os Opensuse-Tumbleweed
PS> # Builtins still there
PS> Get-WslImage -Source Builtins -Os opensuse-tumbleweed

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
opensuse-tumb...  Builtin Opensuse-... 20250820     True            NotDownloaded docker.opensuse-tumbleweed.ro...
opensuse-tumb...  Builtin Opensuse-... 20250820     False           NotDownloaded docker.opensuse-tumbleweed-ba...

PS>
```

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
[incus]: https://linuxcontainers.org/incus/introduction/
[images]: https://github.com/antoinemartin?tab=packages&repo_name=PowerShell-Wsl-Manager
<!-- prettier-ignore-end -->
