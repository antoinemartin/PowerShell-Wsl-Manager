# PowerShell-Wsl-Manager

Wsl-Manager is a Powershell cmdlet to quickly create a minimal WSL distribution.
Currently, it can create a WSL distribution based on the following Linux
distros:

- Archlinux (2025.08.01)
- Alpine (3.22)
- Ubuntu (25.10 questing)
- Debian (13 trixie)
- Any Incus available distribution
  ([list](https://images.linuxcontainers.org/images/))

It is available in PowerShell Gallery as the
[`Wsl-Manager`](https://www.powershellgallery.com/packages/Wsl-Manager) module.

Extended information is available in
[the project documentation](https://mrtn.me/PowerShell-Wsl-Manager/).

## Rationale

Windows is a great development platform for Linux based backend services through
[Visual Studio Code and WSL](https://code.visualstudio.com/docs/remote/wsl).

However, using a single Linux distribution is unpractical as it tends to get
bloated and becomes difficult to recreate if configured manually.

It is much better to use a distribution per development environment given that
the performance overhead is low.

Creating a WSL distribution from a Linux distro Root filesystem
([Ubuntu](https://cloud-images.ubuntu.com/wsl/),
[Arch](https://archive.archlinux.org/iso/2025.08.01/),
[Alpine](https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/)) is
relatively easy but can rapidly become a tedious task.

The `Wsl-Manager` module streamlines that.

## What it does

This module provides a cmdlet called `Install-Wsl` that will install a
lightweight Windows Subsystem for Linux (WSL) distribution.

The installed distribution is configured as follows:

- A user named after the type of distribution (`arch`, `alpine` or `ubuntu`) is
  set as the default user. The user as `sudo` (`doas` on Alpine) privileges.
- zsh with [oh-my-zsh](https://ohmyz.sh/) is used as shell.
- [powerlevel10k](https://github.com/romkatv/powerlevel10k) is set as the
  default oh-my-zsh theme.
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) plugin
  is installed.
- The
  [wsl2-ssh-pageant](https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin)
  plugin is installed in order to use the GPG private keys available at the
  Windows level both for SSH and GPG (I personally use a Yubikey).

You can install an already configured distribution (`-Configured` flag) or start
from the official root filesystem and perform the configuration locally on the
newly created distribution.

The root filesystems from which the WSL distributions are created are cached in
the `%LOCALAPPDATA%\Wsl\RootFS` directory when downloaded and reused for further
creations.

By default, each created WSL distribution home folder (where the `ext4.vhdx`
virtual filesystem file is located) is located in `%LOCALAPPDATA%\Wsl`

## Pre-requisites

WSL 2 needs to be installed and working. If you are on Windows 11, a simple
`wsl --install` should get you going.

To install this module, you need to be started with the
[PowerShell Gallery](https://docs.microsoft.com/en-us/powershell/scripting/gallery/getting-started?view=powershell-7.2).

The WSL distribution uses a fancy zsh theme called
[powerlevel10k](https://github.com/romkatv/powerlevel10k). To work properly in
the default configuration, you need a [Nerd Font](https://www.nerdfonts.com/).
My personal advice is to use `Ubuntu Mono NF` available via [scoop](scoop.sh) in
the nerds font bucket:

```bash
❯ scoop bucket add nerd-fonts
❯ scoop install UbuntuMono-NF-Mono
```

The font name is then `'UbuntuMono NF'` (for vscode, Windows Terminal...).

## Getting started

Install the module with:

```bash
❯ Install-Module -Name Wsl-Manager
```

And then create a WSL distribution with:

```bash
❯ Install-Wsl Arch -Distribution Arch
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\dev]...
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2022.11.01/archlinux.rootfs.tar.gz â†’ C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz...
####> Creating distribution [dev]...
####> Running initialization script [configure.sh] on distribution [dev]...
####> Done. Command to enter distribution: wsl -d dev
❯
```

To uninstall the distribution, just type:

```bash
❯ Uninstall-Wsl arch
❯
```

It will remove the distribution and wipe the directory completely.

## Using already configured Filesystems

Configuration implies installing some packages. To avoid the time taken to
download and install such packages, Already configured root filesystems files
are made available as OCI containers on
[GitHub Container Registry](https://github.com/antoinemartin?tab=packages&repo_name=PowerShell-Wsl-Manager).

You can install an already configured distribution by adding the `-Configured`
switch:

```bash
❯ Install-Wsl test2 -Distribution Alpine -Configured
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test2]...
Downloading docker://ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-alpine#latest to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz with filename miniwsl-alpine
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-alpine:latest...
⌛ Getting docker authentication token for registry ghcr.io and repository antoinemartin/powershell-wsl-manager/miniwsl-alpine...
⌛ Getting image manifests from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/miniwsl-alpine/manifests/latest...
⌛ Getting image manifest from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/miniwsl-alpine/manifests/sha256:ec906d1cb2f8917135a9d1d03dd2719e2ad09527e8d787434f0012688111920d...
👀 Root filesystem size: 35,4 MB. Digest sha256:a10a24a60fcd632be07bcd6856185a3346be72ecfcc7109366195be6f6722798. Downloading...
sha256:a10a24a60fcd632be07bcd6856185a3346be72ecfcc7109366195be6f6722798 (35,4 MB) [=======================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz.tmp
👀 Downloaded file size: 35,4 MB
🎉 [Alpine:3.22] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz].
⌛ Creating distribution [test2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz]...
🎉 Done. Command to enter distribution: wsl -d test2
❯
```

More documentation and examples are available in
[the project documentation](https://mrtn.me/PowerShell-Wsl-Manager/).
