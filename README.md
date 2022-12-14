# PowerShell-Wsl-Manager

Powershell cmdlet to quickly create a minimal WSL distribution. Currently, it
can create an Archlinux, Alpine (3.17) or Ubuntu (22.10) based distribution. It
is available in PowerShell Gallery as
[`Wsl-Manager`](https://www.powershellgallery.com/packages/Wsl-Manager/1.2.1).

Extended information is available in
[the project documentation](https://mrtn.me/PowerShell-Wsl-Manager/).

## Rationale

Windows is a great development platform for Linux based backend services through
[Visual Studio Code and WSL](https://code.visualstudio.com/docs/remote/wsl).

However, using a single Linux distrbution is unpratictal as it tends to get
bloated and becomes difficult to recreate if configured manually.

It is much better to use a distribution per development envinronment given that
the performance overhead is low.

Creating a WSL distribution from a Linux distro Root filesystem
([Ubuntu](https://cloud-images.ubuntu.com/wsl/),
[Arch](https://archive.archlinux.org/iso/2022.12.01/),
[Alpine](https://dl-cdn.alpinelinux.org/alpine/v3.17/releases/x86_64/)) is
relatively easy but can rapidely become a tedious task.

The `Wsl-Manager` module streamlines that.

## What it does

This module allows to easily create and manage lightweight WSL distributions. It
provides support for the following distros:

- [Alpine (3.17)](https://www.alpinelinux.org/) is the lightest and allows
  developing in the same environment as most docker containers.
- [Arch Linux](https://archlinux.org/) is the most up to date and versatile.
- [Ubunty (22.10)](https://ubuntu.com/) is the most used. In particular, it
  allows simulating the Github Actions runner.

It provides a cmdlet called `Install-Wsl` that will install a lightweight
Windows Subsystem for Linux (WSL) distribution.

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
newly created distrbution.

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

```console
❯ scoop bucket add nerd-fonts
❯ scoop install UbuntuMono-NF-Mono
```

The font name is then `'UbuntuMono NF'` (for vscode, Windows Terminal...).

## Getting started

Install the module with:

```console
❯ Install-Module -Name Wsl-Manager
```

And then create a WSL distribution with:

```console
❯ Install-Wsl Arch -Distribution Arch
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\dev]...
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2022.11.01/archlinux.rootfs.tar.gz â†’ C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz...
####> Creating distribution [dev]...
####> Running initialization script [configure_arch.sh] on distribution [dev]...
####> Done. Command to enter distribution: wsl -d dev
❯
```

To uninstall the distribution, just type:

```console
❯ Uninstall-Wsl dev
❯
```

It will remove the distrbution and wipe the directory completely.

## Using already configured Filesystems

Configuration implies installing some packages. To avoid the time taken to
download and install such packages, Already configured root filesystems files
are made available on
[github](https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/tag/latest).

You can install an already configured distrbution by adding the `-Configured`
switch:

```powershell
❯ install-wsl test2 -Distribution Alpine -Configured
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test2]...
####> Downloading  https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz...
####> Creating distribution [test2]...
####> Done. Command to enter distribution: wsl -d test2
❯
```

## Example: Creating a distribution hosting docker

You can create a distribution for building docker images. We will use Arch for
this example.

First install the distribution:

```powershell
❯ install-Wsl docker -Distribution Arch
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\docker]...
####> Arch Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz].
####> Creating distribution [docker]...
####> Running initialization script [configure_arch.sh] on distribution [docker]...
####> Done. Command to enter distribution: wsl -d docker
❯
```

Connect to it as root and install docker:

```bash
# Add docker to the distribution
❯ wsl -d docker -u root pacman -Sy --noconfirm --needed docker
:: Synchronizing package databases...
 core is up to date
 extra is up to date
 community is up to date
resolving dependencies...
looking for conflicting packages...

Packages (5) bridge-utils-1.7.1-1  containerd-1.6.10-1  libtool-2.4.7-5  runc-1.1.4-1  docker-1:20.10.21-1

Total Download Size:    54.85 MiB
Total Installed Size:  240.09 MiB

:: Proceed with installation? [Y/n]
:: Retrieving packages...
...
:: Processing package changes...
...
:: Running post-transaction hooks...
...
(4/4) Arming ConditionNeedsUpdate...
❯
```

Add the `arch` user to the docker group:

```bash
# Adding base user as docker
❯ wsl -d docker -u root usermod -aG docker arch
```

Now, with this distribution, you can add the following alias to
`%USERPROFILE%\Documents\WindowsPowerShell\profile.ps1`:

```powershell
function RunDockerInWsl {
  # Take $Env:DOCKER_WSL or 'docker' if undefined
  $DockerWSL = if ($null -eq $Env:DOCKER_WSL) { "docker" } else { $Env:DOCKER_WSL }
  # Try to find an existing distribution with the name
  $existing = Get-Wsl $DockerWSL

  # Ensure docker is started
  wsl.exe -d $existing.Name /bin/sh "-c" "test -f /var/run/docker.pid || sudo -b sh -c 'dockerd -p /var/run/docker.pid -H unix:// >/var/log/docker.log 2>&1'"
  # Perform the requested command
  wsl.exe -d $existing.Name /usr/bin/docker $Args
}

Set-Alias -Name docker -Value RunDockerInWsl
```

and run docker directly from powershell:

```powershell
❯ docker run --rm -it alpine:latest /bin/sh
Unable to find image 'alpine:latest' locally
latest: Pulling from library/alpine
c158987b0551: Pull complete
Digest: sha256:8914eb54f968791faf6a8638949e480fef81e697984fba772b3976835194c6d4
Status: Downloaded newer image for alpine:latest
/ # exit
❯
```

You can save the distrbution root filesystem for reuse:

```powershell
❯ Export-Wsl docker
####> Exporting WSL distribution docker to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.rootfs.tar...
####> Compressing C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.rootfs.tar to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.rootfs.tar.gz...                                                                                                                                   ####> Distribution docker saved to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.rootfs.tar.gz
❯
```

And then create another distribution in the same state from the exported root
filesystem:

```powershell
❯ Install-Wsl docker2 -Distribution docker
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\docker2]...                                                                                                                                                                                                                   ####> Creating distribution [docker2]...                                                                                                                                                                                                                                                         ####> Done. Command to enter distribution: wsl -d docker2
```

You can then flip between the two distrbutions:

```powershell
# Run nginx in docker distribution
❯ docker run -d -p 8080:80 --name nginx nginx:latest
Unable to find image 'nginx:latest' locally
latest: Pulling from library/nginx
a603fa5e3b41: Pull complete
c39e1cda007e: Pull complete
90cfefba34d7: Pull complete
a38226fb7aba: Pull complete
62583498bae6: Pull complete
9802a2cfdb8d: Pull complete
Digest: sha256:e209ac2f37c70c1e0e9873a5f7231e91dcd83fdf1178d8ed36c2ec09974210ba
Status: Downloaded newer image for nginx:latest
61f5993c6e1ad87a35f1d6dacef917b5f6d0951bdd3e5c31840870bdac028f91
# View it running
❯ docker ps
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         PORTS                                   NAMES
61f5993c6e1a   nginx:latest   "/docker-entrypoint.…"   7 seconds ago   Up 6 seconds   0.0.0.0:8080->80/tcp, :::8080->80/tcp   nginx
# Switch to other distribution
❯ $env:DOCKER_WSL="docker2"
# Clean docker instance !
❯ docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```
