# PowerShell-Wsl-Manager

Powershell cmdlet to quickly create a minimal WSL distribution. Currently, it
can create an Archlinux, Alpine (3.17) or Ubuntu (22.10) based distribution. It
is available in PowerShell Gallery as
[`Wsl-Manager`](https://www.powershellgallery.com/packages/Wsl-Manager/1.1.1).

This project is generalization of its sister project
[PowerShell-Wsl-Alpine](https://github.com/antoinemartin/PowerShell-Wsl-Alpine).

## Rationale

As a developer working mainly on Linux, I have the tendency to put everything in
the same WSL distribution, ending up with a distribution containing Go, Python,
Terraform...

This module is here to reduce the time of spawning a new distrbution for
development in order to have concerns more splitted. It is also a reminder of
the congfiguration steps to have a working distribution.

## What it does

This module provides a cmdlet called `Install-Wsl` that will install a
lightweight Windows Subsystem for Linux (WSL) distribution.

This command performs the following operations:

- Create a Distribution directory,
- Download the Root Filesystem,
- Create the WSL distribution,
- Configure the WSL distribution.

The distribution is configured as follows:

- A user named after the type of distribution (`arch`, `alpine` or `ubuntu`) is
  set as the default user. The user as `sudo` (`doas` on Alpine) privileges.
- zsh with [oh-my-zsh](https://ohmyz.sh/) is used as shell.
- [powerlevel10k](https://github.com/romkatv/powerlevel10k) is set as the
  default oh-my-zsh theme.
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) plugin
  is installed.
- The
  [wsl2-ssh-pageant](https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin)
  plugin is installed in order to use the GPG keys private keys available at the
  Windows level (I personally use a Yubikey).

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
> scoop bucket add nerd-fonts
> scoop install UbuntuMono-NF-Mono
```

The font name is then `'UbuntuMono NF'` (for vscode, Windows Terminal...).

## Getting started

Install the module with:

```console
> Install-Module -Name Wsl-Manager
```

And then create a WSL distribution with:

```console
> Install-Wsl Arch -Distribution Arch
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\dev]...
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2022.11.01/archlinux.rootfs.tar.gz â†’ C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\arch.rootfs.tar.gz...
####> Creating distribution [dev]...
####> Running initialization script [configure_arch.sh] on distribution [dev]...
####> Done. Command to enter distribution: wsl -d dev
>
```

To uninstall the distribution, just type:

```console
> Uninstall-Wsl dev
>
```

It will remove the distrbution and wipe the directory completely.

## Using already configured Filesystems

Configuration implies installing some packages. To avoid the time taken to
download and install such packages, Already configured root images are made
available on
[github](https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/tag/latest).

You can install an already configured distrbution by adding the `-Configured`
switch:

````powershell
ﬀ install-wsl test2 -Distribution Alpine -Configured
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test2]...
####> Downloading  https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.alpine.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz...
####> Creating distribution [test2]...
####> Done. Command to enter distribution: wsl -d test2
ﬀ


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
````

Connect to it as root and install docker:

```bash
# Connect to the distribution
❯ wsl -d docker -u root
[powerlevel10k] fetching gitstatusd .. [ok]
# Add docker
❯ pacman -Sy --noconfirm --needed docker
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
❯ usermod -aG docker arch
```

Now, with this distribution, you can add the following alias to
`%USERPROFILE%\Documents\WindowsPowerShell\profile.ps1`:

```powershell
function RunDockerInWsl {
  # Take $Env:DOCKER_WSL or 'docker' if undefined
  $DockerWSL = if ($null -eq $Env:DOCKER_WSL) { "docker" } else { $Env:DOCKER_WSL }
  # Try to find an existing distribution with the name
  $existing = Get-ChildItem HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Lxss |  Where-Object { $_.GetValue('DistributionName') -eq $DockerWSL }
  if ($null -eq $existing) {
    # Fail if the distribution doesn't exist
    throw "The WSL distribution [$DockerWSL] does not exist !"
  } else {
    # Ensure docker is started
    wsl -d $DockerWSL /bin/sh -c "test -f /var/run/docker.pid || sudo -b sh -c 'dockerd -p /var/run/docker.pid -H unix:// >/var/log/docker.log 2>&1'"
    # Perform the requested command
    wsl -d $DockerWSL /usr/bin/docker $args
  }
}

Set-Alias -Name docker -Value RunDockerInWsl
```

and run docker directly from powershell:

```powershell
ﬀ docker run --rm -it alpine:latest /bin/sh
Unable to find image 'alpine:latest' locally
latest: Pulling from library/alpine
c158987b0551: Pull complete
Digest: sha256:8914eb54f968791faf6a8638949e480fef81e697984fba772b3976835194c6d4
Status: Downloaded newer image for alpine:latest
/ # exit
ﬀ
```

You can save the distrbution root filesystem for reuse:

```powershell
ﬀ Export-Wsl docker
####> Exporting WSL distribution docker to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.rootfs.tar...
####> Compressing C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.rootfs.tar to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.rootfs.tar.gz...                                                                                                                                   ####> Distribution docker saved to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.rootfs.tar.gz
ﬀ
```

And then create another distribution in the same state from the exported root
filesystem:

```powershell
ﬀ Install-Wsl docker2 -Distribution docker
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\docker2]...                                                                                                                                                                                                                   ####> Creating distribution [docker2]...                                                                                                                                                                                                                                                         ####> Done. Command to enter distribution: wsl -d docker2
```

You can then flip between the two distrbutions:

```powershell
# Run nginx in docker distribution
ﬀ docker run -d -p 8080:80 --name nginx nginx:latest
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
ﬀ docker ps
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         PORTS                                   NAMES
61f5993c6e1a   nginx:latest   "/docker-entrypoint.…"   7 seconds ago   Up 6 seconds   0.0.0.0:8080->80/tcp, :::8080->80/tcp   nginx
# Switch to other distribution
ﬀ $env:DOCKER_WSL="docker2"
# Clean docker instance !
ﬀ docker ps
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

## Development

To modify the module, clone it in your local modules directory:

```console
> cd $env:USERPROFILE\Documents\WindowsPowerShell\Modules\
> git clone https://github.com/antoinemartin/PowerShell-Wsl-Manager Wsl-Manager
```

## TODO

- [x] Add a switch to avoid the configuration of the distribution.
- [x] Document the customization of the distrbution.
- [x] Add a command to export the current filesystem and use it as input for
      other distrbutions.
- [x] Allow publication of the module through github actions.
- [x] Publish the customized root filesystem to improve startup.
