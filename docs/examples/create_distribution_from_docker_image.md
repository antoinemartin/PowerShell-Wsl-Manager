---
description: |
  Learn how to create custom WSL distributions from Docker images using multiple methods.
  Transform container filesystems into WSL images for development environments
  that mirror production runtime containers.
---

## Use cases

It is sometimes useful to make your development environment close to the
production runtime environment. If the code you are developing runs on a Docker
or Kubernetes container, It can be useful to develop _inside_ your docker image.

This is particularly useful in interpreted languages like Python or Node, less
in compiled languages as you tend to have separate _builder_ and _production_
images.

However, you can
[develop on an actual container](https://code.visualstudio.com/docs/devcontainers/containers).
But there are still some advantages to use WSL:

- Somewhat easier to setup.
- Persistent. Unless you delete the WSL distribution, it will stay there.
- You don't need an IDE or a never ending process to keep your environment
  alive.
- You can browse the environment with the explorer (`\\wsl$`)

Another use case is to use a `Dockerfile` as the **_recipe_** to create your WSL
distribution image. You can leverage the entire Docker ecosystem, including
build optimizations, multi-stage builds, layer caching, and alternative build
tools like `buildah` or `buildctl` for more advanced scenarios.

## Caveats

A docker image does not pack _only_ the filesystem. It also contains other
useful information like the environment variables, the current user, working
directory and startup command. All this cannot be translated _as is_ in a WSL
distribution.

What you can do most of the time is gather this information and add it to the
`.zshrc` file or any environment file.

## Pre-requisites

The methods shown here will use the Alpine configured distribution as the
_workbench_ because it is the smallest one and the fastest to instantiate.
Create and enter the instance by typing the following command in a powershell
terminal:

```ps1con
PS> nwsl builder -From alpine | iwsl -User root
nwsl builder -From alpine | iwsl
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\builder]...
⌛ Creating instance [builder] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.alpine.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In builder or wsl -d builder
[powerlevel10k] fetching gitstatusd .. [ok]
  /mnt/c/Users/AntoineMartin                                                                                13:04:29
❯
```

!!! note

    Alpine has also the advantage of using OpenRC instead of Systemd as its init
    system. As the former doesn't need to be run on PID 1, it is easily launched
    and kept alive. This is handy for running docker or Kubernetes.

## Creating a WSL image from an existing Docker image

### Method 1: Skipping docker (skopeo and umoci)

The first method uses [skopeo] to download the layers of the docker image and
[umoci] to flatten them.

We first create the following script inside the WSL instance:

=== ":octicons-terminal-16: Script creation command"

    with the following linux terminal commands:

    ```bash
    cat - >~/script.sh <<'EOF'
    --8<-- "docs/examples/docker_export_skopeo.sh"
    EOF
    chmod +x ~/script.sh
    ```

=== ":octicons-file-code-16: script.sh source"

    ```bash
    --8<-- "docs/examples/docker_export_skopeo.sh"
    ```

Then we run the script with the proper image and tag parameters:

```bash
  /mnt/c/Users/AntoineMartin                                                                                                                                                                                       11s  11:36:06
❯ ~/script.sh postgres latest
(1/9) Installing acl-libs (2.3.2-r1)
(2/9) Installing lz4-libs (1.10.0-r0)
(3/9) Installing xz-libs (5.8.1-r0)
(4/9) Installing libarchive-tools (3.8.1-r0)
(5/9) Installing containers-common (0.64.1-r0)
(6/9) Installing gpgme (1.24.2-r2)
(7/9) Installing skopeo (1.20.0-r0)
(8/9) Installing umoci (0.4.7-r32)
(9/9) Installing skopeo-zsh-completion (1.20.0-r0)
Executing busybox-1.37.0-r10.trigger
OK: 87 MiB in 97 packages
Getting image source signatures
Copying blob b7a79609094c done   |
Copying blob f5465e2fc020 done   |
Copying blob c166c949e1c3 done   |
Copying blob 7fa725c973af done   |
Copying blob 1f6dfcaad4e9 done   |
Copying blob 396b1da7636e done   |
Copying blob 901a9540064a done   |
Copying blob 085f0a899c07 done   |
Copying blob 5d91a345d79a done   |
Copying blob f7f2afaa1b41 done   |
Copying blob 36b4e7f51364 done   |
Copying blob 85558a023eea done   |
Copying blob be9fdbdba096 done   |
Copying blob ae28e2b99a62 done   |
Copying config ca95f67ffb done   |
Writing manifest to image destination
  /mnt/c/Users/AntoineMartin                                                                                                                                                                                       11s  11:36:06
❯ exit
PS>
```

We can then check our produced image and play with it:

```ps1con
PS> # Check that the image is present
PS> Get-WslImage

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
...(omitted for brevity)...
postgres            Local Debian       13           False                  Synced postgres.rootfs.tar.gz

PS> # Install the distribution
PS> new-WslInstance ps -From postgres | Invoke-WslConfigure | Invoke-WslInstance
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\ps]...
⌛ Creating instance [ps] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\postgres.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In ps or wsl -d ps
⌛ Running initialization script [C:\Users\AntoineMartin\Documents\WindowsPowerShell\Modules\Wsl-Manager/configure.sh] on instance [ps.Name]...
🎉 Configuration of instance [ps] completed successfully.
[powerlevel10k] fetching gitstatusd .. [ok]
  /mnt/c/Users/AntoineMartin                                                                                13:54:32
❯
```

### Method 2: With docker and buildx

This method takes advantage of [BuildKit] that is integrated in recent versions
of docker and the [buildx] client that targets these new features. In
particular, we are interested in the `--output` feature that allows flattening
the image in a tar file.

!!! note

    By the way, the following method also shows how to install docker on an alpine
    distribution.

We run the following command in the WSL instance to create the script:

=== ":octicons-terminal-16: Script creation command"

    with the following linux terminal commands:

    ```bash
    cat - >~/script.sh <<'EOF'
    --8<-- "docs/examples/docker_export_buildx.sh"
    EOF
    chmod +x ~/script.sh
    ```

=== ":octicons-file-code-16: script.sh source"

    ```bash
    --8<-- "docs/examples/docker_export_buildx.sh"
    ```

Then we run the script with the appropriate image and tag:

```ps1con
PS> # Run it with the appropriate parameters
PS> wsl -d builder -u root /root/script.sh python slim
OK: 362 MiB in 108 packages
[+] Building 8.2s (5/5) FINISHED
 => [internal] load build definition from Dockerfile                                                                                                     0.0s
 => => transferring dockerfile: 54B                                                                                                                      0.0s
 => [internal] load .dockerignore                                                                                                                        0.0s
 => => transferring context: 2B                                                                                                                          0.0s
 => [internal] load metadata for docker.io/library/python:slim                                                                                           1.3s
 => [1/1] FROM docker.io/library/
 ...                                              0.1s
 => exporting to client                                                                                                                                  4.7s
 => => sending tarball
```

We can check that the image is present:

```ps1con
PS> # alias for Get-WslImage
PS> gwsli

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
...(omitted for brevity)...
python              Local Debian       13           False                  Synced python.rootfs.tar.gz

PS>
```

As the docker image is debian based, the distribution can be configured as if it
were a builtin one. We can check that it installs and configures:

```ps1con
PS> # Equivalent to New-WslInstance py -From python | Invoke-WslConfigure | Invoke-WslInstance
PS>  nwsl py -From python | cwsl | iwsl
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\py]...
⌛ Creating instance [py] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In py or wsl -d py
⌛ Running initialization script [C:\Users\AntoineMartin\Documents\WindowsPowerShell\Modules\Wsl-Manager/configure.sh] on instance [py.Name]...
🎉 Configuration of instance [py] completed successfully.
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(debian) gid=1000(debian) groups=1000(debian),50(staff)
❯ python --version
Python 3.13.7
  /mnt/c/Users/AntoineMartin                                                                                14:08:22
❯ exit
PS>
```

We can keep the configuration for further instantiations by exporting the
distribution and overriding the non configured one:

```ps1con
PS> # Export it and replace preceding one
PS> Export-WslInstance py -OutputName python
⌛ Exporting WSL instance py to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar...
: ./home/debian/.ssh/agent.sock: pax format cannot archive sockets: ./home/debian/.gnupg/S.gpg-agent: pax format cannot archive sockets⌛ Compressing C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz...
🎉 Instance py saved to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz.

Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
python              Local debian       13           True                   Synced python.rootfs.tar.gz

PS>
```

We can check that the instantiation is now much faster and that the default user
is `debian`:

```ps1con
PS>  remove-WslInstance py; New-WslInstance py -From python | Invoke-WslInstance
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\py]...
⌛ Creating instance [py] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In py or wsl -d py
❯ id
uid=1000(debian) gid=1000(debian) groups=1000(debian),50(staff)
  /mnt/c/Users/AntoineMartin                                                                                14:35:41
❯ exit
```

## Using docker to customize the images

The following `Dockerfile`[^1] is the docker equivalent of the `configure.sh`
script for the builtin Alpine image:

[^1]: This file is `Dockerfile` at the root of the project.

??? example "Sample Dockerfile"

    ```dockerfile title="Dockerfile"
    --8<-- "Dockerfile"
    ```
    1. Test from code annotation

Some remarks about the `Dockerfile`:

- It has no external dependencies. You can build the image without any
  additional files.
- Some of the image content downloaded from github making the resulting image
  non reproducible and with potential security issues.
- The dockerfile contains a builder container and a final single layer
  container. The resulting image can be pushed to a registry and used by Wsl
  Manager with a `docker://` URI.

You can build the image inside `builder`, the WSL instance running docker:

```bash
PS> wsl -d builder
❯ # Get $Env:LOCALAPPDATA as a Linux path
❯ local=$(wslpath $(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -NoLogo -C '$env:LOCALAPPDATA' | tr -d '\r'))
❯ # Build and export the image directly to the WSL Manager cache
❯ docker buildx build --output type=tar . | gzip > "$local/Wsl/RootFS/test.rootfs.tar.gz"
 => [internal] load build definition from Dockerfile                                                                                                     0.0s
...
 => exporting to client                                                                                                                                  2.5s
 => => sending tarball
❯ exit
```

You can check that the built image is _known_ to Wsl Manager and instantiate it:

```ps1con
PS> # Check that the image is present
PS> Get-WslImage
Name                 Type Os           Release      Configured              State FileName
----                 ---- --           -------      ----------              ----- --------
...(omitted for brevity)...
test                Local Alpine       3.22.0_al... False                  Synced test.rootfs.tar.gz

PS> # Instantiate and enter the instance
PS> New-WslInstance test -From test | Invoke-WslInstance
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test]...
⌛ Creating instance [test] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\test.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In test or wsl -d test
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(alpine) gid=1000(alpine) groups=10(wheel),1000(alpine)
  /mnt/c/Users/AntoineMartin                                                                                15:43:11
❯
```

[skopeo]: https://github.com/containers/skopeo
[umoci]: https://github.com/opencontainers/umoci
[buildkit]: https://docs.docker.com/build/buildkit/
[buildx]: https://docs.docker.com/build/install-buildx/
