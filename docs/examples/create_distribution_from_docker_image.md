---
description: |
    Learn how to create custom WSL distributions from Docker images using multiple methods.
    Transform container filesystems into WSL root filesystems for development environments
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

-   Somewhat easier to setup.
-   Persistent. Unless you delete the WSL distribution, it will stay there.
-   You don't need an IDE or a never ending process to keep your environment
    alive.
-   You can browse the environment with the explorer (`\\wsl$`)

Another use case is to use a `Dockerfile` as the **_recipe_** to create your WSL
distribution root filesystem. You can leverage the entire Docker ecosystem,
including build optimizations, multi-stage builds, layer caching, and
alternative build tools like `buildah` or `buildctl` for more advanced
scenarios.

## Caveats

A docker image does not pack _only_ the filesystem. It also contains other
useful information like the environment variables, the current user, working
directory and startup command. All this cannot be translated _as is_ in a WSL
distribution.

What you can do most of the time is gather this information and add it to the
`.zshrc` file or any environment file.

## Pre-requisites

The methods shown here will use the Alpine configured distribution as base
because it is the smallest one and the fastest to instantiate. It is installed
with the following command:

```bash
PS> Install-Wsl builder -Distribution Alpine -Configured
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\builder]...
👀 [Alpine:3.19] Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz].
⌛ Creating distribution [builder] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz]...
🎉 Done. Command to enter distribution: wsl -d builder
PS>
```

!!! note

    Alpine has also the advantage of using OpenRC instead of Systemd. As the former
    doesn't need to be run on PID 1, it is easily launched and kept alive. This is
    handy for running docker or Kubernetes.

## Method 1: Skipping docker (skopeo and umoci)

The first method uses [skopeo] to download the layers of the docker image and
[umoci] to flatten them.

We first create the following script:

```bash
#!/usr/bin/env zsh

# Retrieve image and tag from parameters
image=$1
tag=$2

# Create a temporary directory as destination of the image
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd $dir

# Add the needed dependencies
apk add skopeo umoci libarchive-tools

# Retrieve the image
skopeo copy docker://$image:$tag oci:$image:$tag

# Unpack the image in the image subfolder
umoci unpack --image $image:$tag image

# Create the root filesystem
bsdtar -cpf $image.rootfs.tar.xz -C image/rootfs $(ls image/rootfs/)

# Move the filesystem where Wsl-Manager can find it
local=$(cmd.exe /c '<nul set /p=%LOCALAPPDATA%')
mv $image.rootfs.tar.xz $(wslpath "$local")/Wsl/RootFS/$image.rootfs.tar.gz

```

with the following powershell commands:

```bash
PS> $source=@'
#!/usr/bin/env zsh

# Retrieve image and tag from parameters
image=$1
tag=$2

# Create a temporary directory as destination of the image
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd $dir

# Add the needed dependencies
apk add skopeo umoci libarchive-tools

# Retrieve the image
skopeo copy docker://$image:$tag oci:$image:$tag

# Unpack the image in the image subfolder
umoci unpack --image $image:$tag image

# Create the root filesystem
bsdtar -cpf $image.rootfs.tar.xz -C image/rootfs $(ls image/rootfs/)

# Move the filesystem where Wsl-Manager can find it
local=$(cmd.exe /c '<nul set /p=%LOCALAPPDATA%')
mv $image.rootfs.tar.xz $(wslpath "$local")/Wsl/RootFS/$image.rootfs.tar.gz
# keep this last line comment
'@
PS> # Export the script inside the builder distribution
PS>  $source | wsl -d builder -u root zsh -c "cat - >/root/script.sh;chmod +x /root/script.sh"
```

Then we run the script with the proper image and tag parameters:

```bash
PS # Run it with the appropriate parameters
PS> wsl -d builder -u root /root/script.sh postgres latest
fetch https://dl-cdn.alpinelinux.org/alpine/v3.19/main/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.19/community/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/edge/testing/x86_64/APKINDEX.tar.gz
(1/10) Installing libacl (2.3.1-r1)
(2/10) Installing lz4-libs (1.9.4-r1)
(3/10) Installing zstd-libs (1.5.2-r9)
(4/10) Installing libarchive-tools (3.6.1-r2)
(5/10) Installing containers-common (0.50.1-r0)
(6/10) Installing device-mapper-libs (2.03.19-r1)
(7/10) Installing gpgme (1.18.0-r0)
(8/10) Installing skopeo (1.10.0-r3)
(9/10) Installing umoci (0.4.7-r12)
(10/10) Installing skopeo-zsh-completion (1.10.0-r3)
Executing busybox-1.35.0-r29.trigger
OK: 88 MiB in 95 packages
Getting image source signatures
Copying blob 4eacfb0464b2 done
Copying blob 048d3078d446 done
Copying blob c6d23b4fe6c1 done
Copying blob 3f4ca61aafcd done
Copying blob d846f6946dd5 done
Copying blob 76f7157f330d done
Copying blob 5c197e2b597b done
Copying blob 2c4576649951 done
Copying blob 1ae267d32d50 done
Copying blob 03048c1132b5 done
Copying blob bdee410b6909 done
Copying blob d3354a8bfb14 done
Copying blob 0105a87d8ff9 done
Copying config 87b6b3723c done
Writing manifest to image destination
Storing signatures
'\\wsl.localhost\builder\tmp\tmp.kDaIIE'
CMD.EXE a été démarré avec le chemin d’accès comme répertoire en
cours. Les chemins d’accès UNC ne sont pas prise en charge. Utilisation
du répertoire Windows par défaut.
```

We can then check our produced root filesystem and play with it:

```bash
PS> # Check that the root filesystem is present
PS> Get-WslRootFileSystem -Type Local

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
   Local Docker       unknown                Synced docker.rootfs.tar.gz
   Local jekyll       3.19.1                 Synced jekyll.rootfs.tar.gz
   Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
   Local Postgres     unknown                Synced postgres.rootfs.tar.gz
PS> # Make the filesystem configurable
PS> Get-WslRootFileSystem -Os postgres | %{$_.Configured=$false;$_.WriteMetadata() }
PS> # Install the distribution
Install-Wsl ps -Distribution postgres
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\ps]...
👀 [Postgres:unknown] Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\postgres.rootfs.tar.gz].
⌛ Creating distribution [ps] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\postgres.rootfs.tar.gz]...
⌛ Running initialization script [configure.sh] on distribution [ps]...
🎉 Done. Command to enter distribution: wsl -d ps
PS> # Run it...
PS> wsl -d ps
>
```

## Method 2: With docker and buildx

This method takes advantage of [BuildKit] that is integrated in recent versions
of docker and the [buildx] client that targets these new features. In
particular, we are interested in the `--output` feature that allows flattening
the image in a filesystem.

!!! note

    By the way, the following method also shows how to install docker on an alpine
    distribution.

First we create the following script:

```bash
#!/usr/bin/env zsh

image=$1
tag=$2

# If docker is not running, ensure it is installed and started
if ! [ -f /var/run/docker.pid ]; then
    apk add docker docker-cli-buildx
    rc-update add docker default
    openrc default
fi

# Create a temporary directory as context of the image
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

# We retrieve the windows local app data
local=$(cmd.exe /c '<nul set /p=%LOCALAPPDATA%')

# We create the docker file.
echo "FROM $image:$tag" > $dir/Dockerfile

# We build the image asking for a tar output
docker buildx b --output type=tar $dir | gzip >$(wslpath "$local")/Wsl/RootFS/$image.rootfs.tar.gz
```

With the following powershell commands:

```bash
PS>$source=@'
#!/usr/bin/env zsh

image=$1
tag=$2

# If docker is not running, ensure it is installed and started
if ! [ -f /var/run/docker.pid ]; then
    apk add docker docker-cli-buildx
    rc-update add docker default
    openrc default
fi

# Create a temporary directory as context of the image
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

# We retrieve the windows local app data
local=$(cmd.exe /c '<nul set /p=%LOCALAPPDATA%')

# We create the docker file.
echo "FROM $image:$tag" > $dir/Dockerfile

# We build the image asking for a tar output
docker buildx b --output type=tar $dir | gzip >$(wslpath "$local")/Wsl/RootFS/$image.rootfs.tar.gz
# Keep this comment
'@
PS> # Export the script inside the builder distribution
PS>  $source | wsl -d builder -u root zsh -c "cat - >/root/script.sh;chmod +x /root/script.sh"
```

Then we run the script with the appropriate image and tag:

```bash
PS # Run it with the appropriate parameters
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

We can check that the root filesystem is present:

```bash
PS> Get-WslRootFileSystem -Type Local

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
   Local Docker       unknown                Synced docker.rootfs.tar.gz
   Local jekyll       3.19.1                 Synced jekyll.rootfs.tar.gz
   Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
   Local Postgres     unknown                Synced postgres.rootfs.tar.gz
   Local Python       unknown                Synced python.rootfs.tar.gz

PS>
```

As the docker image is debian based, the distribution can be configured as if it
were a builtin one. We can modify its metadata accordingly:

```bash
PS> # Set Metadata on root fs and make it configurable
PS> Get-WslRootFileSystem -Os python | % { $_.Configured=$false;$_.Release="3.11";$_.WriteMetadata() }
PS>
```

And then we can check that it installs and is configured:

```bash
PS> Install it with configuration. As this is debian, it will work
PS> Install-Wsl py -Distribution python
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\py]...
👀 [Python:3.11] Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz].
⌛ Creating distribution [py] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz]...
⌛ Running initialization script [configure.sh] on distribution [py]...
🎉 Done. Command to enter distribution: wsl -d py
PS> # check it is configured
PS> wsl -d py
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(debian) gid=1000(debian) groups=1000(debian),50(staff)
❯ exit
```

We can keep the configuration for further instantiations by exporting the
distribution and overriding the non configured one:

```bash
PS> # Export it and replace preceding one
PS> Export-Wsl py -OutputName python
⌛ Exporting WSL distribution py to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar...
⌛ Compressing C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz...
🎉 Distribution py saved to C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz.

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
   Local python       11                     Synced python.rootfs.tar.gz

PS>
```

We can then revert the `Configured` flag on its metadata and test that the
instantiation is now much faster:

```bash
PS> # Change metadata to Already configured
PS> Get-WslRootFileSystem -Os python | % { $_.Configured=$true;$_.Release="3.11";$_.WriteMetadata() }
PS> # Check configuration is ok
PS>  Uninstall-Wsl py; Install-Wsl py -Distribution python
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\py]...
👀 [python:11] Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz].
⌛ Creating distribution [py] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\python.rootfs.tar.gz]...
🎉 Done. Command to enter distribution: wsl -d py
PS>  wsl -d py
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=0(root) gid=0(root) groups=0(root)
❯ exit

```

## Using docker to customize the images

The following `Dockerfile` is the docker equivalent of the `configure.sh` script
for the builtin Alpine image:

```dockerfile
FROM alpine:3.19

# Add the dependencies
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories ;\
    apk update --quiet ;\
    apk add --quiet --no-progress --no-cache zsh tzdata git libstdc++ doas iproute2 gnupg socat openssh openrc

# Change root shell
RUN sed -ie '/^root:/ s#:/bin/.*$#:/bin/zsh#' /etc/passwd

# Add Oh-my-zsh
RUN git clone --quiet --depth 1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh && \
    sed -i -e 's#^export ZSH=.*#export ZSH=/usr/share/oh-my-zsh#g' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    git clone --quiet --depth=1 https://github.com/romkatv/powerlevel10k.git /usr/share/oh-my-zsh/custom/themes/powerlevel10k && \
    git clone --quiet --depth=1  https://github.com/zsh-users/zsh-autosuggestions "/usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions" && \
    git clone --quiet --depth 1 https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin "/usr/share/oh-my-zsh/custom/plugins/wsl2-ssh-pageant" && \
    sed -ie '/^plugins=/ s#.*#plugins=(git zsh-autosuggestions wsl2-ssh-pageant)#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    sed -ie '/^ZSH_THEME=/ s#.*#ZSH_THEME="powerlevel10k/powerlevel10k"#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> /usr/share/oh-my-zsh/templates/zshrc.zsh-template

# OpenRC stuff
RUN mkdir -p /lib/rc/init.d && \
    ln -s /lib/rc/init.d /run/openrc && \
    touch /lib/rc/init.d/softlevel

ADD rc.conf /etc/rc.conf

# Configure root user
USER root
RUN install -m 700 -o root -g root /usr/share/oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc && \
    install --directory -o root -g root -m 0700 /root/.ssh && \
    gpg -k >/dev/null 2>&1

COPY --chown=root:root ./p10k.zsh /root/.p10k.zsh

# Add user alpine
RUN adduser -s /bin/zsh -g alpine -D alpine && \
    addgroup alpine wheel && \
    echo "permit nopass keepenv :wheel" >> /etc/doas.d/doas.conf

# Configure user alpine
USER alpine

RUN install -m 700 -o alpine -g alpine /usr/share/oh-my-zsh/templates/zshrc.zsh-template /home/alpine/.zshrc && \
    install --directory -o alpine -g alpine -m 0700 /home/alpine/.ssh && \
    gpg -k >/dev/null 2>&1

COPY --chown=alpine:alpine ./p10k.zsh /home/alpine/.p10k.zsh

# Run shell by default. Allows using the docker image
CMD /bin/zsh
```

To run it, you need to create it and in the same folder put the `p10k.zsh` file
along with the following `rc.conf` file:

```
# rc.conf
rc_sys="prefix"
rc_controller_cgroups="NO"
rc_depend_strict="NO"
rc_need="!net !dev !udev-mount !sysfs !checkfs !fsck !netmount !logger !clock !modules"
```

Then, inside the builder image running docker:

```bash
PS> wsl -d builder
> local=$(wslpath $(cmd.exe /c '<nul set /p=%LOCALAPPDATA%'))
> docker buildx b --output type=tar . | gzip > "$local/Wsl/RootFS/test.rootfs.tar.gz"
 => [internal] load build definition from Dockerfile                                                                                                     0.0s
...
 => exporting to client                                                                                                                                  2.5s
 => => sending tarball
> exit
```

You retrieve the built filesystem and can instantiate it:

```bash
PS> Get-WslRootFileSystem -Type Local

    Type Os           Release                 State Name
    ---- --           -------                 ----- ----
   Local Docker       unknown                Synced docker.rootfs.tar.gz
   Local jekyll       3.19.1                 Synced jekyll.rootfs.tar.gz
   Local Netsdk       unknown                Synced netsdk.rootfs.tar.gz
   Local Postgres     unknown                Synced postgres.rootfs.tar.gz
   Local python       11                     Synced python.rootfs.tar.gz
   Local Test         unknown                Synced test.rootfs.tar.gz

PS>  Install-Wsl test -Distribution test
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\test]...
👀 [Test:unknown] Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\test.rootfs.tar.gz].
⌛ Creating distribution [test] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\test.rootfs.tar.gz]...
🎉 Done. Command to enter distribution: wsl -d test
PS> Set-WslDefaultUid -Distribution test -Uid 1000
PS > wsl -d test
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(alpine) gid=1000(alpine) groups=10(wheel),1000(alpine)
❯ exit
```

!!! tip

    As you see above, the default user for the distribution has been set with `Set-WslDefaultUid`
    ([reference](../usage/reference/set-wsl-default-uid.md)).

[skopeo]: https://github.com/containers/skopeo
[umoci]: https://github.com/opencontainers/umoci
[buildkit]: https://docs.docker.com/build/buildkit/
[buildx]: https://docs.docker.com/build/install-buildx/
