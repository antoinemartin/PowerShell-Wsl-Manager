# Install distributions

## Minimal distribution

The fastest distribution to install is the already configured Alpine:

```bash
❯ New-WslInstance alpine1 -From Alpine -Configured
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\alpine1]...
Downloading docker://ghcr.io/antoinemartin/powershell-wsl-manager/alpine#latest to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\alpine.rootfs.tar.gz with filename alpine
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine:latest...
⌛ Getting docker authentication token for registry ghcr.io and repository antoinemartin/powershell-wsl-manager/alpine...
⌛ Getting image manifests from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/alpine/manifests/latest...
⌛ Getting image manifest from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/alpine/manifests/sha256:ec906d1cb2f8917135a9d1d03dd2719e2ad09527e8d787434f0012688111920d...
👀 image size: 35,4 MB. Digest sha256:a10a24a60fcd632be07bcd6856185a3346be72ecfcc7109366195be6f6722798. Downloading...
sha256:a10a24a60fcd632be07bcd6856185a3346be72ecfcc7109366195be6f6722798 (35,4 MB) [=======================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\alpine.rootfs.tar.gz.tmp
👀 Downloaded file size: 35,4 MB
🎉 [Alpine:3.22] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\alpine.rootfs.tar.gz].
⌛ Creating distribution [alpine1] from [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\alpine.rootfs.tar.gz]...
🎉 Done. Command to enter distribution: wsl -d alpine1PS❯ wsl -d alpine2
[powerlevel10k] fetching gitstatusd .. [ok]
```

Once the image is downloaded locally, subsequent installations are even faster
because the image is available locally:

```bash
PS❯ New-WslInstance alpine2 -From Alpine -Configured
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\alpine2]...
⌛ Getting docker authentication token for registry ghcr.io and repository antoinemartin/powershell-wsl-manager/alpine...
⌛ Getting image manifests from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/alpine/manifests/latest...
⌛ Getting image manifest from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/alpine/manifests/sha256:ec906d1cb2f8917135a9d1d03dd2719e2ad09527e8d787434f0012688111920d...
👀 [Alpine:3.22] Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\alpine.rootfs.tar.gz].
⌛ Creating distribution [alpine2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\alpine.rootfs.tar.gz]...
🎉 Done. Command to enter distribution: wsl -d alpine2
PS❯ wsl -d alpine2
[powerlevel10k] fetching gitstatusd .. [ok]
wsl❯ exit
PS❯
```

`Get-WslInstance` allows retrieving information about the installed
distributions:

```bash
❯ Get-WslInstance alpine* | format-table -Property *

FileSystemPath BlockFile                                                       Length Name      State Version Default Guid                                 BasePath
-------------- ---------                                                       ------ ----      ----- ------- ------- ----                                 --------
\\wsl$\alpine1 C:\Users\AntoineMartin\AppData\Local\Wsl\alpine1\ext4.vhdx   146800640 alpine1 Stopped       2   False 6c00c83f-bb99-4b6b-b2e6-53dca1c69b29 C:\Users\AntoineMartin\AppData\Local\Wsl\alpine1
\\wsl$\alpine2 C:\Users\AntoineMartin\AppData\Local\Wsl\alpine2\ext4.vhdx   146800640 alpine2 Stopped       2   False b54ef2b7-1ad8-46c2-9b3e-6ec3c6b5d147 C:\Users\AntoineMartin\AppData\Local\Wsl\alpine2
```

## Pre-configured vs unconfigured distributions

The module provides both pre-configured and unconfigured (vanilla) versions of
distributions:

-   **Configured distributions** (using `-Configured` flag) include a pre-setup
    user environment with zsh, oh-my-zsh, and powerlevel10k theme
-   **Unconfigured distributions** provide the base distribution that you can
    customize yourself

For example, to install an unconfigured OpenSuse distribution:

```bash
PS❯ New-WslInstance opensuse1 -From OpenSuse
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\opensuse1]...
Downloading docker://ghcr.io/antoinemartin/powershell-wsl-manager/opensuse-base#latest to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\opensuse-base.rootfs.tar.gz with filename opensuse-base
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/opensuse-base:latest...
🎉 [OpenSuse:tumbleweed] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\opensuse-base.rootfs.tar.gz].
⌛ Creating distribution [opensuse1] from [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\opensuse-base.rootfs.tar.gz]...
⌛ Running initialization script [configure.sh] on distribution [opensuse1]...
🎉 Done. Command to enter distribution: wsl -d opensuse1
```

## Locally configured distribution

Installing a locally configured distribution allows starting from the official
distribution image that contains updated packages:

```bash
PS❯ New-WslInstance ubuntu2210 -From Ubuntu
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\ubuntu2510]...
⌛ Getting checksums from https://cdimages.ubuntu.com/ubuntu-wsl/daily-live/current/SHA256SUMS...
Downloading https://cdimages.ubuntu.com/ubuntu-wsl/daily-live/current/questing-wsl-amd64.wsl to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\ubuntu.rootfs.tar.gz with filename questing-wsl-amd64.wsl
⌛ Downloading https://cdimages.ubuntu.com/ubuntu-wsl/daily-live/current/questing-wsl-amd64.wsl...
questing-wsl-amd64.wsl (369,5 MB) [=======================================================================================================================================================================] 100%
🎉 [Ubuntu:noble] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\ubuntu.rootfs.tar.gz].
⌛ Creating distribution [ubuntu2510] from [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\ubuntu.rootfs.tar.gz]...
⌛ Running initialization script [configure.sh] on distribution [ubuntu2510]...
🎉 Done. Command to enter distribution: wsl -d ubuntu2510
PS❯ wsl -d ubuntu2510
[powerlevel10k] fetching gitstatusd .. [ok]
wsl❯ exit
PS❯
```

## Incus based distributions

[Incus] allows running linux system containers in Linux. It is similar to WSL as
it can use images as source. Canonical provides images for the [most popular
Linux distributions][incus images]. The images built can be browsed
[here][incus image list].

!!! warning

    Incus images may contain more packages than the ones needed for a
    minimal WSL installation. However, they provide a reliable and centralized
    source for Linux distributions.

!!! note

    The complete list of Incus images is available as a JSON file
    [here][json incus image list]. The image details are also available in this
    [json file][json incus images detail] (caution: it is about 2 Megabytes).

Let's imagine that we want to try the Alpine edge distribution. We can type:

```bash
PS> New-WslInstance edge -From incus:alpine:edge
New-WslInstance edge -From incus:alpine:edge                             .
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\edge]...
⌛ Getting checksums from https://images.linuxcontainers.org/images/alpine/edge/amd64/default/20250808_13%3A00/SHA256SUMS...
Downloading https://images.linuxcontainers.org/images/alpine/edge/amd64/default/20250808_13%3A00/rootfs.tar.xz to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\incus.alpine_edge.rootfs.tar.gz with filename rootfs.tar.xz
⌛ Downloading https://images.linuxcontainers.org/images/alpine/edge/amd64/default/20250808_13%3A00/rootfs.tar.xz...
rootfs.tar.xz (3,4 MB) [==================================================================================================================================================================================] 100%
🎉 [alpine:edge] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\incus.alpine_edge.rootfs.tar.gz].
⌛ Creating distribution [edge] from [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\incus.alpine_edge.rootfs.tar.gz]...
⌛ Running initialization script [configure.sh] on distribution [edge]...
🎉 Done. Command to enter distribution: wsl -d edge
PS> wsl -d edge
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(alpine) gid=1000(alpine) groups=10(wheel),1000(alpine)
❯ exit
PS>
```

## Docker based distributions

Docker images can be used to create WSL distributions. The process is similar to
using Incus images, but instead, it pulls the image from a Docker image.

To install a Docker based distribution, you can use the following command:

```bash
PS> New-WslInstance bw -From docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch-base#latest
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\bw]...
⌛ Getting docker authentication token for registry ghcr.io and repository antoinemartin/powershell-wsl-manager/arch-base...
⌛ Getting image manifests from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/arch-base/manifests/latest...
⌛ Getting image manifest from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/arch-base/manifests/sha256:6cb57ed1bcb10105054b1e301afa5cf8e067dc18e1946c5b5f421e8074acbb3d...
⌛ Getting image configuration manifest from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/arch-base/blobs/sha256:c56a57b923448c44cc6d7495bb276c3fc58131ff8203509cd8e2b9183d6ab598...
Downloading docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch-base#latest to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\arch-base.2025.08.01.rootfs.tar.gz with filename arch-base
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/arch-base:latest...
⌛ Getting docker authentication token for registry ghcr.io and repository antoinemartin/powershell-wsl-manager/arch-base...
⌛ Getting image manifests from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/arch-base/manifests/latest...
⌛ Getting image manifest from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/arch-base/manifests/sha256:6cb57ed1bcb10105054b1e301afa5cf8e067dc18e1946c5b5f421e8074acbb3d...
⌛ Getting image configuration manifest from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/arch-base/blobs/sha256:c56a57b923448c44cc6d7495bb276c3fc58131ff8203509cd8e2b9183d6ab598...
👀 image size: 209,5 MB. Digest sha256:63c4520dc98718104f6305850acc5c8e014fe454865d67d5040ac8ebcec98c35. Downloading...
sha256:63c4520dc98718104f6305850acc5c8e014fe454865d67d5040ac8ebcec98c35 (209,5 MB) [======================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\arch-base.2025.08.01.rootfs.tar.gz.tmp
👀 Downloaded file size: 209,5 MB
🎉 [arch-base:2025.08.01] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\arch-base.2025.08.01.rootfs.tar.gz].
⌛ Creating distribution [bw] from [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\arch-base.2025.08.01.rootfs.tar.gz]...
⌛ Running initialization script [configure.sh] on distribution [bw]...
🎉 Done. Command to enter distribution: wsl -d bw
PS> wsl -d bw
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(alpine) gid=1000(alpine) groups=10(wheel),1000(alpine)
❯ exit
PS>
```

This will create a new WSL distribution named `bw` using the image from the
specified Docker image.

!!! warning

    Currently Wsl-Manager only supports docker images that contain only one layer.

---

[incus images]: https://images.linuxcontainers.org/images
[incus image list]: https://images.linuxcontainers.org/images/
[incus]: https://linuxcontainers.org/
[json incus image list]:
    https://images.linuxcontainers.org/imagesstreams/v1/index.json
[json incus images detail]:
    https://images.linuxcontainers.org/imagesstreams/v1/images.json
