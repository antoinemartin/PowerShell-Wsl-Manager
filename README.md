# PowerShell WSL Manager

[![codecov](https://codecov.io/github/antoinemartin/PowerShell-Wsl-Manager/graph/badge.svg?token=GGSLVWO0QG)](https://codecov.io/github/antoinemartin/PowerShell-Wsl-Manager)

A PowerShell module for easily managing WSL _images_ (root filesystems) and
_instances_ (distributions) with pre-configured, lightweight Linux environments.
Like the `Hyper-V` PowerShell module, but focused on WSL.

> **Note**: We use the term "instances" instead of "distributions" because you
> can have multiple instances of the same Linux distribution. We also use
> "images" to refer to root filesystems for consistency with container
> terminology.

## 🚀 Quick Start

Install from PowerShell Gallery and create your first WSL instance:

```powershell
# Install the module
Install-Module -Name Wsl-Manager

# Create a new Arch Linux instance
New-WslInstance arch -From arch

# Enter your new instance
Invoke-WslInstance -In arch
```

## 📦 What's Included

**Wsl-Manager** supports creating WSL instances from these Linux distributions:

- **Archlinux** (2025.08.01)
- **Alpine** (3.22)
- **Ubuntu** (25.10 questing)
- **Debian** (13 trixie)
- **Any Incus distribution**
  ([browse available images](https://images.linuxcontainers.org/images/))

📚 **[Complete Documentation](https://mrtn.me/PowerShell-Wsl-Manager/)**

## ✨ Features

### Pre-Configured Development Environment

Each WSL instance comes with a complete development setup:

- **User Account**: Distribution-specific user (`arch`, `alpine`, `ubuntu`,
  `debian`, `opensuse`) with sudo/doas privileges
- **Shell**: zsh with [oh-my-zsh](https://ohmyz.sh/) framework
- **Theme**: [powerlevel10k](https://github.com/romkatv/powerlevel10k) for
  enhanced terminal experience
- **Plugins**:
  - [zsh-autosuggestions](https://github.com/zsh-users/zsh-autosuggestions) for
    command completion
  - [wsl2-ssh-pageant](https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin)
    for Windows GPG/SSH integration

### Smart Caching System

- Downloaded images are cached in `%LOCALAPPDATA%\Wsl\RootFS`
- Instance data stored in `%LOCALAPPDATA%\Wsl\<InstanceName>`
- Images are pulled from the Github container registry where they are stored as
  single-layer containers.

## 🎯 Why Use WSL Manager?

Windows is excellent for Linux backend development through
[Visual Studio Code and WSL](https://code.visualstudio.com/docs/remote/wsl), but
managing multiple development environments can be challenging.

### The Problem with Single WSL Instances

- **Bloat**: Single instances become cluttered over time
- **Difficult to recreate**: Manual configurations are hard to reproduce
- **Environment conflicts**: Different projects may have conflicting
  requirements

### The WSL Manager Solution

- **Multiple lightweight instances**: Each project gets its own clean
  environment
- **Low performance overhead**: All instances share the same virtual machine
  (the WSL 2 VM)
- **Easy management**: Simple commands to create, manage, and destroy instances
- **Consistent setup**: Pre-configured environments ensure repeatability
- **Image management**: Easily sync, update, and remove images
- **Extensibility**: Customize and extend your WSL instances with additional
  tools and configurations

## 🛠 How It Works

WSL Manager provides cmdlets organized into two main categories:

- **`*-WslImageSource`**: Manage root filesystems (similar to Docker images)
  sources.
- **`*-WslImage`**: Manage root filesystems (downloaded images)
- **`*-WslInstance`**: Manage WSL distributions (running environments)

Complete list of cmdlets: `Get-Command -Module Wsl-Manager`.

### Image Types

- **Configured Images**: Pre-setup with zsh, oh-my-zsh, and development tools
- **Base Images**: Minimal upstream distributions for custom configurations
- **Docker Integration**: Images distributed as single-layer containers via
  GitHub Registry
- **Incus Support**: Create instances from any Incus-compatible distribution

## 📋 Prerequisites

### System Requirements

- **Windows 11** with WSL 2 installed and working
  - Run `wsl --install` in terminal if not already set up
- **PowerShell Gallery** access for module installation

### Recommended Font Setup

The pre-configured instances use
[powerlevel10k](https://github.com/romkatv/powerlevel10k) theme with
[Nerd Fonts](https://www.nerdfonts.com/) for optimal display.

**Quick font installation with Scoop:**

```powershell
scoop bucket add nerd-fonts
scoop install UbuntuMono-NF-Mono
```

Then set your terminal font to `'UbuntuMono NF'` in VS Code, Windows Terminal,
etc.

## 🏁 Getting Started

### Installation

```powershell
Install-Module -Name Wsl-Manager
```

### Create Your First Instance

```powershell
New-WslInstance arch -From arch
```

**Expected output:**

```powershell
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\arch]...
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/arch:latest...
⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/arch:latest from registry ghcr.io...
👀 Root filesystem size: 463,4 MB. Digest sha256:4a2bfff9b492f1b084bf5f8b214058623a762002a342810647a275d2c51f017d. Downloading...
sha256:4a2bfff9b492f1b084bf5f8b214058623a762002a342810647a275d2c51f017d (463,4 MB) [=======================================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\AED22B871CBC5D56C15976CEC7ED30C3140B2638D2BE2D6896B5649A5C19B8A0.rootfs.tar.gz.tmp. File size: 463,4 MB
🎉 [Arch:2025.08.01] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\AED22B871CBC5D56C15976CEC7ED30C3140B2638D2BE2D6896B5649A5C19B8A0.rootfs.tar.gz].
⌛ Creating instance [arch] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\AED22B871CBC5D56C15976CEC7ED30C3140B2638D2BE2D6896B5649A5C19B8A0.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In arch or wsl -d arch

Name                                        State Version Default
----                                        ----- ------- -------
arch                                      Stopped       2   False
```

### Enter Your Instance

```powershell
# Method 1: Using WSL Manager
Invoke-WslInstance -In arch

# Method 2: Using native WSL
wsl -d arch
```

### Basic Instance Management

```powershell
# List all instances
Get-WslInstance

# Remove an instance
Remove-WslInstance arch

# List available images
Get-WslImageSource -Source Builtin

# Download specific images
Sync-WslImage alpine,alpine-base

# Create instance from base image (minimal configuration)
New-WslInstance test -From alpine-base
```

## 💡 Quick Tips

- **Caching**: Downloaded images are cached locally for faster subsequent
  deployments
- **Cleanup**: Removing instances deletes their directories but keeps cached
  images
- **Multiple versions**: Run multiple instances of the same distribution
  simultaneously
- **Custom configs**: Use base images to create your own development
  environments

## 🛠 Command Aliases

WSL Manager provides convenient aliases for easier usage:

```powershell
# Create and immediately enter a new instance
nwsl test -From alpine | iwsl

# List and remove running instances
gwsl -State Running | rmwsl
```

**Common aliases:**

<!-- cSpell:ignore nwsl iwsl gwsl rmwsl -->

- `nwsl` → `New-WslInstance`
- `iwsl` → `Invoke-WslInstance`
- `gwsl` → `Get-WslInstance`
- `rmwsl` → `Remove-WslInstance`

View all aliases: `Get-Command -Module Wsl-Manager -CommandType Alias`

## 📚 More Information

**Complete documentation and examples:**
[https://mrtn.me/PowerShell-Wsl-Manager/](https://mrtn.me/PowerShell-Wsl-Manager/)

**PowerShell Gallery:**
[`Wsl-Manager`](https://www.powershellgallery.com/packages/Wsl-Manager)
