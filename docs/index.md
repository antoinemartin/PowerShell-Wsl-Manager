# WSL Manager

Wsl-Manager is a Powershell module offering cmdlets to quickly create a minimal
WSL distribution. Currently, it can create a WSL distribution based on the
following Linux distributions:

-   [Archlinux]. As this is a _rolling_ distribution, there is no version
    attached. The current image used as base is 2025-08-01.
-   [Alpine] (3.22)
-   [Ubuntu] (25.10 questing)
-   [Debian] (13 trixie)
-   [OpenSuse] (tumbleweed)
-   Any Incus available distribution
    ([list](https://images.linuxcontainers.org/images))

It is available in PowerShell Gallery as the
[`Wsl-Manager`](https://www.powershellgallery.com/packages/Wsl-Manager) module.

## Rationale

Windows is a great development platform for Linux based backend services through
[Visual Studio Code and WSL](https://code.visualstudio.com/docs/remote/wsl).

However, using a single Linux distribution is unpractical as it tends to get
bloated and becomes difficult to recreate if configured manually.

It is much better to use a distribution per development environment given that
the performance overhead is low.

Creating a WSL distribution from a Linux distro image
([Ubuntu](https://cdimages.ubuntu.com/ubuntu-wsl),
[Arch](https://archive.archlinux.org/iso/2025.08.01/),
[Alpine](https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/)) is
relatively easy but can rapidly become a tedious task.

The `Wsl-Manager` module streamlines that.

## What it does

This module provides a cmdlet called `New-WslInstance` that will install a
lightweight Windows Subsystem for Linux (WSL) distribution.

The installed distribution is configured as follows:

-   A user named after the type of distribution (`arch`, `alpine` or `ubuntu`)
    is set as the default user. The user as `sudo` (`doas` on Alpine)
    privileges.
-   zsh with [oh-my-zsh](https://ohmyz.sh/) is used as shell.
-   [powerlevel10k](https://github.com/romkatv/powerlevel10k) is set as the
    default oh-my-zsh theme.
-   [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
    plugin is installed.
-   The
    [wsl2-ssh-pageant](https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin)
    plugin is installed in order to use the GPG private keys available at the
    Windows level both for SSH and GPG (I personally use a Yubikey).

You can install an already configured distribution (`-Configured` flag) or start
from the official image and perform the configuration locally on the newly
created distribution.

The images from which the WSL distributions are created are cached in the
`%LOCALAPPDATA%\Wsl\Image` directory when downloaded and reused for further
creations. See the [Manage images](usage/manage-root-filesystems.md) page for
more details.

By default, each created WSL distribution home folder (where the `ext4.vhdx`
virtual filesystem file is located) is located in `%LOCALAPPDATA%\Wsl`

[archlinux]: https://archlinux.org/
[alpine]: https://www.alpinelinux.org/
[ubuntu]: https://ubuntu.org
[debian]: https://debian.org
[opensuse]: https://www.opensuse.org
