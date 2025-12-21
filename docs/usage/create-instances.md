# Create instances

## Your first instances

### List builtin images

The available builtin images can be listed using `Get-WslImageSource`:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> Get-WslImageSource
    ⌛ Fetching Builtin images from: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json

    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    alpine-base       Builtin Alpine       3.23.2       False              3.5 MB 12/21/2025 7:20:37 …
    alpine            Builtin Alpine       3.23.2       True              35.5 MB 12/21/2025 7:20:37 …
    ...

    PS>
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS> Get-WslImageSource
    ⌛ Fetching Builtin images from: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/builtins.rootfs.json

    Name                 Type Distribution Release      Configured         Length UpdateDate
    ----                 ---- ------------ -------      ----------         ------ ----------
    alpine-base       Builtin Alpine       3.23.2       False              3.5 MB 12/21/2025 7:20:37 …
    alpine            Builtin Alpine       3.23.2       True              35.5 MB 12/21/2025 7:20:37 …
    arch-base         Builtin Arch         2025.12.01   False            209.3 MB 12/21/2025 7:20:37 …
    arch              Builtin Arch         2025.12.01   True             375.9 MB 12/21/2025 7:20:37 …
    debian-base       Builtin Debian       13           False             29.4 MB 12/21/2025 7:20:37 …
    debian            Builtin Debian       13           True             141.7 MB 12/21/2025 7:20:37 …
    opensuse-tumble…  Builtin Opensuse-Tu… 20251217     False             46.4 MB 12/21/2025 7:20:37 …
    opensuse-tumble…  Builtin Opensuse-Tu… 20251217     True             108.6 MB 12/21/2025 7:20:37 …
    ubuntu-base       Builtin Ubuntu       26.04        False            377.6 MB 12/21/2025 7:20:37 …
    ubuntu            Builtin Ubuntu       26.04        True             430.8 MB 12/21/2025 7:20:37 …

    PS>
    ```

### Create two instances

The fastest instance to install is the already configured Alpine:

=== ":octicons-terminal-16: Powershell"

    ```ps1con
    PS> New-WslInstance alpine1 -From alpine
    ...

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
    👀 Root filesystem size: 36,1 MB. Digest sha256:f9a746c7483d4df04350f166aec2e50a316240dd2c73383fa7614069d8a10bb3. Downloading...
    sha256:f9a746c7483d4df04350f166aec2e50a316240dd2c73383fa7614069d8a10bb3 (36,1 MB) [========================================================================================================================================] 100%
    🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz.tmp. File size: 36,1 MB
    🎉 [Alpine:3.23.2] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz].
    ⌛ Creating instance [alpine1] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz]...
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
    ⌛ Creating instance [alpine2] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7AD24DC5DF6E0.rootfs.tar.gz]...
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

    FileSystemPath   BlockFile      Length Configured Image         Name        State Version Default Guid                                 ImageGuid                            ImageDigest
    --------------   ---------      ------ ---------- -----         ----        ----- ------- ------- ----                                 ---------                            -----------
    \\wsl$\alpine2   ext4.vhdx   180355072       True Alpine:3.23.2 alpine2   Stopped       2   False 0e2c2a81-76b6-4237-972e-8b5a6ea827f9 32031732-dd91-4d42-a715-5d59c0dd5d3d 0926BDEB3848F8B06D2572641DCD801D3CC31EC74AD7A0C3B5D7A...
    \\wsl$\alpine1   ext4.vhdx   180355072       True Alpine:3.23.2 alpine1   Stopped       2   False aa223a0e-fd3b-491d-8d95-6f4644e0dc94 32031732-dd91-4d42-a715-5d59c0dd5d3d F9A746C7483D4DF04350F166AEC2E50A316240DD2C73383FA7614...

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
PS> Get-WslImageSource

Name                 Type Distribution Release      Configured         Length UpdateDate
----                 ---- ------------ -------      ----------         ------ ----------
alpine-base       Builtin Alpine       3.23.2       False              3.5 MB 12/21/2025 7:20:37 …
alpine            Builtin Alpine       3.23.2       True              35.5 MB 12/21/2025 7:20:37 …
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
    PS❯ New-WslInstance opensuse1 -From opensuse-tumbleweed-base | Invoke-WslInstance
    ...
    AMG16:/mnt/c/Users/AntoineMartin #
    ```

=== ":octicons-device-desktop-16: Complete Console output"

    ```ps1con
    PS❯  New-WslInstance opensuse1 -From opensuse-tumbleweed-base | Invoke-WslInstance
    👀 Instance directory [C:\Users\AntoineMartin\AppData\Local\Wsl\opensuse1] already exists.
    ⌛ Downloading Docker image layer from ghcr.io/antoinemartin/powershell-wsl-manager/opensuse-tumbleweed-base:latest...
    ⌛ Retrieving docker image manifest for antoinemartin/powershell-wsl-manager/opensuse-tumbleweed-base:latest from registry ghcr.io...
    👀 Root filesystem size: 72,3 MB. Digest sha256:de2590c2ae9f0c96ec0fa0cbd4c26cde5b444fe598a9d852728a8aca71a728c4. Downloading...
    sha256:de2590c2ae9f0c96ec0fa0cbd4c26cde5b444fe598a9d852728a8aca71a728c4 (72,3 MB) [========================================================================================================================================] 100%
    🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B9A5C4CCC29EB077323F8995FD6DB7E32778DC32EF932438584CA6A83F722203.rootfs.tar.gz.tmp. File size: 72,3 MB
    🎉 [Opensuse-Tumbleweed:20251217] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B9A5C4CCC29EB077323F8995FD6DB7E32778DC32EF932438584CA6A83F722203.rootfs.tar.gz].
    ⌛ Creating instance [opensuse1] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\B9A5C4CCC29EB077323F8995FD6DB7E32778DC32EF932438584CA6A83F722203.rootfs.tar.gz]...
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

[Incus] (the successor of LXD) allows running linux system containers in Linux.
It is similar to WSL as it can use images as source. Canonical provides images
for the [most popular Linux instances][incus images]. The images built can be
browsed [here][incus image list].

!!! warning

    Incus images may contain more packages than the ones needed for a
    minimal WSL installation. However, they provide a reliable and centralized
    source for Linux instances.

You can list the available Incus images with the following command:

```ps1con
PS> Get-WslImageSource -Source Incus
⌛ Fetching Incus images from: https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/rootfs/incus.rootfs.json

Name                 Type Distribution Release      Configured         Length UpdateDate
----                 ---- ------------ -------      ----------         ------ ----------
almalinux           Incus Almalinux    10           False             80,0 MB 21/12/2025 19:56:37
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
👀 Instance directory [C:\Users\AntoineMartin\AppData\Local\Wsl\edge] already exists.
⌛ Downloading https://images.linuxcontainers.org/images/alpine/edge/amd64/default/20251215_13:00/rootfs.tar.xz...
rootfs.tar.xz (3,5 MB) [===================================================================================================================================================================================================] 100%
🎉 [Alpine:edge] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\36022856723EF3E98953408396F054806B965908CB8E0783385F279E414F4B7D.rootfs.tar.gz].
⌛ Creating instance [edge] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\36022856723EF3E98953408396F054806B965908CB8E0783385F279E414F4B7D.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In edge or wsl -d edge
⌛ Running initialization script [C:\Users\AntoineMartin\Documents\WindowsPowerShell\Modules\Wsl-Manager/configure.sh] on instance [edge]...
🎉 Configuration of instance [edge] completed successfully.
[powerlevel10k] fetching gitstatusd .. [ok]
  /mnt/c/Users/AntoineMartin
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
PS> New-WslInstance yawsldocker -From docker://ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine#latest | Invoke-Wsl -U root openrc default
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\yawsldocker]...
⌛ Retrieving docker image manifest for antoinemartin/yawsldocker/yawsldocker-alpine:latest from registry ghcr.io...
⌛ Downloading Docker image layer from ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine:latest...
⌛ Retrieving docker image manifest for antoinemartin/yawsldocker/yawsldocker-alpine:latest from registry ghcr.io...
👀 Root filesystem size: 148,5 MB. Digest sha256:e5e971e5bec2b431de1a8e745c3454a1e60674ca60a1d666816f11debed42665. Downloading...
sha256:e5e971e5bec2b431de1a8e745c3454a1e60674ca60a1d666816f11debed42665 (148,5 MB) [=======================================================================================================================================] 100%
🎉 Successfully downloaded Docker image layer to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\E5E971E5BEC2B431DE1A8E745C3454A1E60674CA60A1D666816F11DEBED42665.rootfs.tar.gz.tmp. File size: 148,5 MB
🎉 [Alpine:3.22.1] Synced at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\E5E971E5BEC2B431DE1A8E745C3454A1E60674CA60A1D666816F11DEBED42665.rootfs.tar.gz].
⌛ Creating instance [yawsldocker] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\E5E971E5BEC2B431DE1A8E745C3454A1E60674CA60A1D666816F11DEBED42665.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In yawsldocker or wsl -d yawsldocker
 * Caching service dependencies ...                                                                 [ ok ]
 * Remounting filesystems ...                                                                       [ ok ]
 * Mounting local filesystems ...                                                                   [ ok ]
 * /var/lib/buildkit: creating directory
 * /var/log/buildkitd.log: creating file
 * Starting buildkitd ...                                                                           [ ok ]
mount: mounting cgroup2 on /sys/fs/cgroup failed: Resource busy
 * /var/log/docker.log: creating file
 * /var/log/docker.log: correcting owner
 * Starting Docker Daemon ...                                                                       [ ok ]
PS>
```

This will create a new WSL instance named `yawsldocker` using the image from the
specified Docker image.

!!! warning

    Currently Wsl-Manager only supports docker images that contain only one layer. See [Why single layer images?](../index.md#why-single-layer-images).

## Delete unused instances

You can delete all the previously created instances with the following command:

```ps1con
PS> Remove-WslInstance edge,opensuse1,alpine1,alpine2,yawsldocker
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
