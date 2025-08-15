# Quick Start

## Pre-requisites

WSL 2 needs to be installed and working. If you are on Windows 11, a simple
`wsl --install` should get you going.

To install this module, you need to be started with the
[PowerShell Gallery](https://docs.microsoft.com/en-us/powershell/scripting/gallery/getting-started?view=powershell-7.2).

The WSL distribution uses a fancy zsh theme called
[powerlevel10k](https://github.com/romkatv/powerlevel10k). To work properly in
the default configuration, you need a [Nerd Font](https://www.nerdfonts.com/).
My personal advice is to use `Ubuntu Mono NF` available via
[scoop](https://scoop.sh) in the nerds font bucket:

```bash
PS> scoop bucket add nerd-fonts
PS> scoop install UbuntuMono-NF-Mono
```

The font name is then `'UbuntuMono NF'` (for vscode, Windows Terminal...).

## Getting started

Install the module with:

```bash
PS> Install-Module -Name Wsl-Manager
```

And then create a WSL distribution with:

```bash
PS> Install-Wsl arch -Distribution Arch
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\arch]...
Downloading docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch-base#latest to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz with filename arch-base
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/arch-base:latest...
⌛ Getting docker authentication token for registry ghcr.io and repository antoinemartin/powershell-wsl-manager/arch-base...
⌛ Getting image manifests from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/arch-base/manifests/latest...
⌛ Getting image manifest from https://ghcr.io/v2/antoinemartin/powershell-wsl-manager/arch-base/manifests/sha256:6cb57ed1bcb10105054b1e301afa5cf8e067dc18e1946c5b5f421e8074acbb3d...
👀 Root filesystem size: 209,5 MB. Digest sha256:63c4520dc98718104f6305850acc5c8e014fe454865d67d5040ac8ebcec98c35. Downloading...
sha256:63c4520dc98718104f6305850acc5c8e014fe454865d67d5040ac8ebcec98c35 (209,5 MB) [======================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz.tmp
👀 Downloaded file size: 209,5 MB
🎉 [Arch:current] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz].
⌛ Creating distribution [arch] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz]...
⌛ Running initialization script [configure.sh] on distribution [arch]...
🎉 Done. Command to enter distribution: wsl -d arch❯
```

As suggested by the command, you can enter the distribution with:

```bash
PS> wsl -d arch
PS C:\Users\AntoineMartin\Documents\WindowsPowerShell\Modules\Wsl-Manager> wsl -d arch
[powerlevel10k] fetching gitstatusd .. [ok]
# id
uid=1000(arch) gid=1000(arch) groups=1000(arch),998(wheel),999(adm)
# exit
PS>
```

You can get the installed distributions with:

```bash
PS> Get-Wsl

Name                                        State Version Default
----                                        ----- ------- -------
arch                                      Running       2   False
```

To uninstall the distribution, just type:

```bash
PS> Uninstall-Wsl arch
PS>
```

It will remove the distribution and wipe the directory completely.

## Using already configured Filesystems

When the module performs the configuration of the distribution, it install some
packages. To avoid the time taken to download and install such packages, Already
configured root filesystems files are made available as OCI containers on
[github](https://github.com/antoinemartin?tab=packages&repo_name=PowerShell-Wsl-Manager).

You can install an already configured distribution by adding the `-Configured`
switch:

```bash
PS> install-wsl test2 -Distribution Alpine -Configured
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
PS>
```
