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

This module is here to reduce the cost of spawning a new distrbution for
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
  set as the default user. The user as `sudo` privileges.
- zsh with [oh-my-zsh](https://ohmyz.sh/) is used as shell.
- [powerlevel10k](https://github.com/romkatv/powerlevel10k) is set as the
  default oh-my-zsh theme.
- [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) plugin
  is installed.
- The
  [wsl2-ssh-pageant](https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin)
  plugin is installed in order to use the GPG keys private keys available at the
  Windows level (I'm using a Yubikey).

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
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Arch]...
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/22.11.01/archlinux.rootfs.tar.gz â†’ C:\Users\AntoineMartin\AppData\Local\Arch\rootfs.tar.gz...
####> Creating distribution [Arch]...
####> Running initialization script on distribution [Arch]...
####> Done. Command to enter distribution: wsl -d Arch
>
```

To uninstall the distribution, just type:

```console
> Uninstall-Wsl Arch
>
```

It will remove the distrbution and wipe the directory completely.

## Example: Creating a distribution hosting docker

You can create a distribution for building docker images. Fist install the
distribution:

```powershell
❯ install-Wsl docker -Distribution Arch
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\docker]...
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/22.11.01/archlinux.rootfs.tar.gz â†’ C:\Users\AntoineMartin\AppData\Local\docker\rootfs.tar.gz...
####> Creating distribution [docker]...
####> Running initialization script on distribution [docker]...
####> Done. Command to enter distribution: wsl -d docker
❯
```

Then connect to it as root and install docker:

```bash
# Connect to the distribution
❯ wsl -d docker -u root
[powerlevel10k] fetching gitstatusd .. [ok]
# Add docker
❯ pacman -Sy --noconfirm docker
:: Synchronizing package databases...
 core is up to date
 extra is up to date
 community is up to date
resolving dependencies...
looking for conflicting packages...

Packages (5) bridge-utils-1.7.1-1  containerd-1.6.4-1  libtool-2.4.7-2  runc-1.1.2-1  docker-1:20.10.16-1
...
(4/4) Arming ConditionNeedsUpdate..
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
❯ docker run --rm -it arch:latest /bin/sh
Unable to find image 'arch:latest' locally
latest: Pulling from library/arch
df9b9388f04a: Pull complete
Digest: sha256:4edbd2beb5f78b1014028f4fbb99f3237d9561100b6881aabbf5acce2c4f9454
Status: Downloaded newer image for arch:latest
/ # exit
```

You can save the distrbution root filesystem for reuse:

```powershell
❯ Export-Wsl docker -OutputFile $env:USERPROFILE\Downloads\archdocker.tar.gz
Distribution docker saved to C:\Users\AntoineMartin\Downloads\archdocker.tar.gz
```

And then create another distribution in the same state from the exported root
filesystem:

```powershell
❯ Install-Wsl docker2 -SkipConfigure -RootFSURL file://$env:USERPROFILE\Downloads\archdocker.tar.gz
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\docker2]...
####> Downloading file://C:\Users\AntoineMartin\Downloads\archdocker.tar.gz â†’ C:\Users\AntoineMartin\AppData\Local\docker2\rootfs.tar.gz...
####> Creating distribution [docker2]...
####> Done. Command to enter distribution: wsl -d docker2
❯ $env:DOC
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
❯
```

You can then flip between the two distrbutions:

```powershell
# Run nginx in docker distribution
❯ docker run -d -p 8080:80 nginx:latest
docker run -d -p 8080:80 nginx:latest
Unable to find image 'nginx:latest' locally
latest: Pulling from library/nginx
214ca5fb9032: Pull complete
66eec13bb714: Pull complete
17cb812420e3: Pull complete
56fbf79cae7a: Pull complete
c4547ad15a20: Pull complete
d31373136b98: Pull complete
Digest: sha256:2d17cc4981bf1e22a87ef3b3dd20fbb72c3868738e3f307662eb40e2630d4320
Status: Downloaded newer image for nginx:latest
7763bf39f6ebc07dd26b51514a2adcc9297aea377b7d465b4d02d04597de19c6
# View it running
❯ docker ps
CONTAINER ID   IMAGE          COMMAND                  CREATED              STATUS              PORTS                                   NAMES
7763bf39f6eb   nginx:latest   "/docker-entrypoint.…"   About a minute ago   Up About a minute   0.0.0.0:8080->80/tcp, :::8080->80/tcp   confident_ride
# Switch to other distribution
❯ $Env:DOCKER_WSL="docker2"
# Clean docker instance !
❯ docker ps
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
- [ ] Allow publication of the module through github actions.
- [ ] Publish the customized root filesystem to improve startup.
