# PowerShell-Wsl-Manager

Wsl-Manager is a Powershell module providing cmdlets to easily manage WSL root
filesystems and distributions.

!!! note

    We use the term "instances" instead of "distributions" because you
    can have multiple instances of the same Linux distribution. We also use
    "images" to refer to root filesystems for consistency with container
    terminology.

It provides pre-configured images based on the following Linux distributions:

- [Archlinux]. As this is a _rolling_ distribution, there is no version
  attached. The current image used as base is 2025-08-01.
- [Alpine] (3.22)
- [Ubuntu] (25.10 questing)
- [Debian] (13 trixie)
- [OpenSuse] (tumbleweed)

It can also create instances from any Incus available distribution
([list](https://images.linuxcontainers.org/images))

It is available in PowerShell Gallery as the
[`Wsl-Manager`](https://www.powershellgallery.com/packages/Wsl-Manager) module.

## Rationale

Windows is a great development platform for Linux based backend services through
[Visual Studio Code and WSL](https://code.visualstudio.com/docs/remote/wsl).

However, using a single WSL instance is unpractical as it tends to get bloated
and becomes difficult to recreate if configured manually.

It is much better to use an instance per development environment given that the
performance overhead is low (because all instances run on the WSL 2 hidden
virtual machine).

Creating a WSL instance from a Linux distribution Root filesystem
([Ubuntu](https://cloud-images.ubuntu.com/wsl/),
[Arch](https://archive.archlinux.org/iso/2025.08.01/),
[Alpine](https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/)) is
relatively easy but can rapidly become challenging.

That's where the `Wsl-Manager` module comes in. It allows managing WSL images
and create WSL instances from them.

You can think of it as the equivalent of the [`Hyper-V` PowerShell
module][hyperv], but focused on WSL.

## How it works

WSL Manager provides cmdlets organized into two main categories:

- **`*-WslImage`**: Manage images (gzipped tar root filesystems)
- **`*-WslInstance`**: Manage WSL distributions (running environments, called
  instances)

The images (gzipped tar root filesystems) are cached in the
`$Env:LOCALAPPDATA\Wsl\RootFS` directory when downloaded and used for creating
instances (with `wsl --import`).

By default, the home folder hosting the instance `ext4.vhdx` virtual filesystem
is located in `$Env:LOCALAPPDATA\Wsl` (i.e. `$Env:LOCALAPPDATA\Wsl\arch` for the
`arch` instance).

The cmdlets output PowerShell objects representing the images (`[WSLImage]`
class) and instances (`[WSLInstance]` class). These objects can be used in
powershell pipes. Example:

```powershell
# Get all alpine based images
Get-WslImage | Where-Object { $_.Os -eq 'Alpine' }

# Synchronize (pull) a docker image, create an instance from it and start services
Sync-WslImage 'docker://ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine#latest' `
  | New-WslInstance test `
  | Invoke-WslInstance -User root openrc default
```

## Builtin images

The project provides a set of pre-configured lightweight images (_builtins_)
that are configured as follows:

- A user named after the type of distribution (`arch`, `alpine`, `ubuntu`,
  `debian` or `opensuse`) is set as the default user with the Uid `1000`. The
  user has `sudo` (`doas` on Alpine) privileges.
- The default shell is zsh
- [oh-my-zsh](https://ohmyz.sh/) is installed for theme management and plugin
  support. It is configured with:
  - **Theme**: [powerlevel10k](https://github.com/romkatv/powerlevel10k)
  - **Plugins**:
    - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions)
      for command auto-suggestions
    - [builtin git plugin](https://github.com/ohmyzsh/ohmyzsh/tree/master/plugins/git)
    - [wsl2-ssh-pageant](https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin)
      allows using the GPG private keys available at the Windows level both for
      SSH and GPG (allowing global use of a Yubikey or any other smart card).

The builtin images are stored as public **single** layer docker images in the
[GitHub container registry][images].

??? question "Why single layer images?"

    WSL only supports importing images from gzipped tar files. Docker images
    are stored as a series of layers. Each layer represents a set of **file
    changes** (additions, modifications, deletions) compared to the previous
    layer in a format called "layered file system". Docker creates a file system
    that combines all layers into a final single layer using a linux feature.

    File deletions from a previous layer are represented in a layer as
    [_whiteout files_][whiteouts].

    In order to create a final `tar.gz` file, Wsl Manager would have to manage
    the _squashing_ of the different layers into a single layer, including
    the management of the whiteout files. To avoid this burden, the builtin
    images are created as single layer.

    Note that at the time of this writing, the [wsl2-distro-manager] GUI tool
    performs the squashing of layers incorrectly as it does not properly handle
    the whiteout files.

The upstream images from which the configured ones are derived are also provided
as builtin images. Those images can be used as a starting point for creating new
WSL images.

[archlinux]: https://archlinux.org/
[alpine]: https://www.alpinelinux.org/
[ubuntu]: https://ubuntu.org
[debian]: https://debian.org
[opensuse]: https://www.opensuse.org
[hyperv]:
  https://learn.microsoft.com/en-us/windows-server/virtualization/hyper-v/powershell
[images]:
  https://github.com/antoinemartin?tab=packages&repo_name=PowerShell-Wsl-Manager
[whiteouts]:
  https://github.com/opencontainers/image-spec/blob/main/layer.md#whiteouts
[wsl2-distro-manager]: https://github.com/bostrot/wsl2-distro-manager
