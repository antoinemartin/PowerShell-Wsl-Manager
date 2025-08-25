# Create instances

## Your first instances

### List builtin images

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

### Create two instances

The fastest instance to install is the already configured Alpine:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> New-WslInstance alpine1 -From alpine

    Name                                        State Version Default
    ----                                        ----- ------- -------
    alpine1                                   Stopped       2   False

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> New-WslInstance alpine1 -From Alpine
    ⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\alpine1]...
    ⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/alpine:latest...
    ⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/alpine:latest from registry ghcr.io...
    👀 Root filesystem size: 35,4 MB. Digest sha256:8f5f9a84bf11de7ce1f74c9b335df99e321f72587c66ae2c0f8e0778e1d7b0b4. Downloading...
    sha256:8f5f9a84bf11de7ce1f74c9b335df99e321f72587c66ae2c0f8e0778e1d7b0b4 (35,4 MB) [===========================] 100%
    🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz.tmp. File size: 35,4 MB
    🎉 [Alpine:3.22.1] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz].
    ⌛ Creating instance [alpine1] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz]...
    🎉 Done. Command to enter instance: Invoke-WslInstance -In alpine1 or wsl -d alpine1

    Name                                        State Version Default
    ----                                        ----- ------- -------
    alpine1                                   Stopped       2   False

    PS>
    ```

Once the image is downloaded locally, subsequent installations are even faster
because the image is available locally:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> New-WslInstance alpine2 -From alpine

    Name                                        State Version Default
    ----                                        ----- ------- -------
    alpine2                                   Stopped       2   False

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> New-WslInstance alpine2 -From Alpine
    ⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\alpine2]...
    ⌛ Creating instance [alpine2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz]...
    🎉 Done. Command to enter instance: Invoke-WslInstance -In alpine2 or wsl -d alpine2

    Name                                        State Version Default
    ----                                        ----- ------- -------
    alpine2                                   Stopped       2   False

    PS>
    ```

`Get-WslInstance` allows retrieving information about the installed instances:

=== ":octicons-terminal-16: Simple view"

    ```ps1con
    PS> Get-WslInstance alpine*

    Name                                        State Version Default
    ----                                        ----- ------- -------
    alpine1                                   Stopped       2   False
    alpine2                                   Stopped       2   False

    PS>
    ```

=== ":octicons-terminal-16: Detailed view"

    ```ps1con
    PS> Get-WslInstance alpine* | Format-Table -Property *

    FileSystemPath   BlockFile      Length Configured Name        State Version Default Guid                                 DefaultUid BasePath
    --------------   ---------      ------ ---------- ----        ----- ------- ------- ----                                 ---------- --------
    \\wsl$\alpine1   ext4.vhdx   146800640       True alpine1   Stopped       2   False a220c6ba-2980-4fbe-8fc7-0d9a9c09177a       1000 C:\Users\AntoineMartin\AppData\Local\Wsl\alpine1
    \\wsl$\alpine2   ext4.vhdx   146800640       True alpine2   Stopped       2   False cd2e8a64-69bd-49b4-b1fb-73c2baef0a04       1000 C:\Users\AntoineMartin\AppData\Local\Wsl\alpine2

    PS>
    ```

### Use the instances

You can enter the first created instance with `wsl -d alpine1` as well as with
`Invoke-WslInstance -In alpine1`:

```ps1con
PS> Invoke-WslInstance -In alpine1
[powerlevel10k] fetching gitstatusd .. [ok]
  /mnt/c/Users/AntoineMartin                                                         14:51:59
❯
```

!!! warning

    Be sure to have installed a Nerd Font as explained in the [pre-requisites](../quick-start.md#pre-requisites)

As you can see, you get into an fancy shell. It is powered by zsh and includes
the powerful powerlevel10k theme. You are greeted with a prompt that shows your
current directory and Git status. You are in the `alpine` user context, and are
part of the admin group with `doas` privileges:

```console
❯ id
uid=1000(alpine) gid=1000(alpine) groups=10(wheel),1000(alpine)
❯ doas apk upgrade
fetch ... (omitted for brevity)
OK: 51 MiB in 90 packages
  /mnt/c/Users/AntoineMartin                                                                                14:59:35
❯
```

## Configured vs base instances

The module provides both _configured_ and unconfigured (vanilla) versions of
instances:

```ps1con
PS> Get-WslImage -Source Builtins

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
alpine            Builtin Alpine       3.22.1       True                   Synced docker.alpine.rootfs.tar.gz
alpine-base       Builtin Alpine       3.22.1       False           NotDownloaded docker.alpine-base.rootfs.tar.gz
...
```

### Configured instances

**Configured instances** are prepared as follows:

- A user named after the distribution (`arch`, `alpine`, `ubuntu`, `debian` or
  `opensuse`) is set as the default user with the Uid `1000`. The user has
  `sudo` (`doas` on Alpine) privileges.
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

### Base instances

**Unconfigured instances** are created from the base image without any
additional configuration. In those instances, the default (and only) user is
`root`. The shell is the default base shell of the distribution.

For example, you can install and enter into an unconfigured OpenSuse instance:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS❯ New-WslInstance opensuse1 -From opensuse-base | Invoke-WslInstance
    ...
    AMG16:/mnt/c/Users/AntoineMartin #
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS❯ New-WslInstance opensuse1 -From opensuse-base
    ⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\opensuse1]...
    ⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/opensuse-base:latest from registry ghcr.io...
    ⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/opensuse-base:latest...
    ⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/opensuse-base:latest from registry ghcr.io...
    👀 Root filesystem size: 71,4 MB. Digest sha256:dc232ac754878e88d86ea813dc56a35973ad4c98c37259ecc624fd18bcaa35b0. Downloading...
    sha256:dc232ac754878e88d86ea813dc56a35973ad4c98c37259ecc624fd18bcaa35b0 (71,4 MB) [===========================] 100%
    🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.opensuse-base.rootfs.tar.gz.tmp. File size: 71,4 MB
    🎉 [Opensuse-Tumbleweed:20250813] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.opensuse-base.rootfs.tar.gz].
    ⌛ Creating instance [opensuse1] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.opensuse-base.rootfs.tar.gz]...
    🎉 Done. Command to enter instance: Invoke-WslInstance -In opensuse1 or wsl -d opensuse1
    AMG16:/mnt/c/Users/AntoineMartin #
    ```

The instance is unconfigured:

```console
AMG16:/mnt/c/Users/AntoineMartin # id
uid=0(root) gid=0(root) groups=0(root)
AMG16:/mnt/c/Users/AntoineMartin # getent passwd
root:x:0:0:root:/root:/bin/bash
messagebus:x:499:499:User for D-Bus:/run/dbus:/usr/sbin/nologin
AMG16:/mnt/c/Users/AntoineMartin #
```

### Configure an instance locally

You can configure a base instance locally by using the `Invoke-WslConfigure`
cmdlet. For example, for the `opensuse1` instance created above:

```ps1con
PS> Invoke-WslConfigure opensuse1
 Invoke-WslConfigure opensuse1
⌛ Running initialization script [C:\Users\AntoineMartin\Documents\WindowsPowerShell\Modules\Wsl-Manager/configure.sh] on instance [opensuse1.Name]...
🎉 Configuration of instance [opensuse1.Name] completed successfully.

Name                                        State Version Default
----                                        ----- ------- -------
opensuse1                                 Stopped       2   False

PS>
```

Now when entering in the instance, you get a fully configured environment:

```ps1con
PS> Invoke-WslInstance -In opensuse1
[powerlevel10k] fetching gitstatusd .. [ok]
  /mnt/c/Users/AntoineMartin                                                                                13:26:29
❯ id
uid=1000(opensuse) gid=1000(opensuse) groups=1000(opensuse),42(trusted)
  /mnt/c/Users/AntoineMartin                                                                                13:27:06
❯
```

The embedded configuration script is able to configure any of the builtin image
distributions, namely:

- Arch Linux
- Alpine
- Debian
- Ubuntu
- OpenSuse

But also alternate ones such as:

- Almalinux
- Rockylinux
- Centos

!!! tip "Running configuration several times"

    The configuration script creates a file named `/etc/wsl-configured` in the
    configured distribution in order to avoid performing the configuration twice.
    It tries however to be idempotent.

    You can delete it with `Invoke-WslInstance -In opensuse1 sudo rm /etc/wsl-configured` and
    perform the configuration again, if needed.

## Incus based instances

[Incus] allows running linux system containers in Linux. It is similar to WSL as
it can use images as source. Canonical provides images for the [most popular
Linux instances][incus images]. The images built can be browsed
[here][incus image list].

!!! warning

    Incus images may contain more packages than the ones needed for a
    minimal WSL installation. However, they provide a reliable and centralized
    source for Linux instances.

You can list the available Incus images with the following command:

```ps1con
PS> Get-WslImage -Source Incus

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
almalinux           Incus almalinux    8            False           NotDownloaded incus.almalinux_8.rootfs.tar.gz
...(rest omitted for brevity)

PS>
```

!!! note

    The original and complete list of Incus images is available as a JSON file
    [here][json incus image list]. The image details are also available in this
    [json file][json incus images detail] (caution: it is about 2 Megabytes).

Let's imagine that we want to try the Alpine edge instance, configure it and
enter it. We can type:

```ps1con
PS> New-WslInstance edge -From incus://alpine#edge | Invoke-WslConfigure | Invoke-Wsl
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\edge]...
⌛ Getting checksums from https://images.linuxcontainers.org/images/alpine/edge/amd64/default/20250824_13:00/SHA256SUMS...
⌛ Downloading https://images.linuxcontainers.org/images/alpine/edge/amd64/default/20250824_13:00/rootfs.tar.xz...
rootfs.tar.xz (3,4 MB) [======================================================================================] 100%
🎉 [alpine:edge] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\incus.alpine_edge.rootfs.tar.gz].
⌛ Creating instance [edge] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\incus.alpine_edge.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In edge or wsl -d edge
⌛ Running initialization script [C:\Users\AntoineMartin\Documents\WindowsPowerShell\Modules\Wsl-Manager/configure.sh] on instance [edge]...
🎉 Configuration of instance [edge.Name] completed successfully.
[powerlevel10k] fetching gitstatusd .. [ok]
  /mnt/c/Users/AntoineMartin                                                                                14:02:30
❯  cat /etc/os-release
NAME="Alpine Linux"
ID=alpine
VERSION_ID=3.23.0_alpha20250612
PRETTY_NAME="Alpine Linux edge"
HOME_URL="https://alpinelinux.org/"
BUG_REPORT_URL="https://gitlab.alpinelinux.org/alpine/aports/-/issues"
  /mnt/c/Users/AntoineMartin                                                                                14:07:53
❯
```

## Docker based instances

Docker images can be used to create WSL instances. The process is similar to
using Incus images, but instead, it pulls the image from a Docker image.

The following command, for instance, creates and start an instance running
docker:

```ps1con
PS> New-WslInstance docker -From docker://ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine#latest | Invoke-Wsl -U root openrc default
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\docker]...
⌛ Retrieving docker image manifest for antoinemartin/yawsldocker/yawsldocker-alpine:latest from registry ghcr.io...
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine:latest...
⌛ Retrieving docker image manifest for antoinemartin/yawsldocker/yawsldocker-alpine:latest from registry ghcr.io...
👀 Root filesystem size: 148,5 MB. Digest sha256:e5e971e5bec2b431de1a8e745c3454a1e60674ca60a1d666816f11debed42665. Downloading...
sha256:e5e971e5bec2b431de1a8e745c3454a1e60674ca60a1d666816f11debed42665 (148,5 MB) [==========================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.yawsldocker-alpine.rootfs.tar.gz.tmp. File size: 148,5 MB
🎉 [Alpine:3.22.1] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.yawsldocker-alpine.rootfs.tar.gz].
⌛ Creating instance [docker] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.yawsldocker-alpine.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In docker or wsl -d docker
 * Caching service dependencies ...                                                                               [ ok ]
 * Remounting filesystems ...                                                                                     [ ok ]
 * Mounting local filesystems ...                                                                                 [ ok ]
 * /var/lib/buildkit: creating directory
 * /var/log/buildkitd.log: creating file
 * Starting buildkitd ...                                                                                         [ ok ]
 * /var/log/docker.log: creating file
 * /var/log/docker.log: correcting owner
 * Starting Docker Daemon ...                                                                                     [ ok ]
PS>
```

This will create a new WSL instance named `docker` using the image from the
specified Docker image.

!!! warning

    Currently Wsl-Manager only supports docker images that contain only one layer. See [Why single layer images?](../index.md#why-single-layer-images).

## Delete unused instances

You can delete all the previously created instances with the following command:

```ps1con
PS> Remove-WslInstance edge,opensuse1,alpine1,alpine2,docker
PS>
```

---

[incus images]: https://images.linuxcontainers.org/images
[incus image list]: https://images.linuxcontainers.org/images/
[incus]: https://linuxcontainers.org/
[json incus image list]:
  https://images.linuxcontainers.org/imagesstreams/v1/index.json
[json incus images detail]:
  https://images.linuxcontainers.org/imagesstreams/v1/images.json
