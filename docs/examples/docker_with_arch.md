---
description: |
    Set up an Arch Linux WSL distribution as a lightweight alternative to Docker Desktop for container development on Windows.
---

You can create a distribution for building docker images. We will use Arch for
this example.

First install the distribution:

```bash
❯ install-Wsl docker -From Arch
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\docker]...
####> Arch Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\Image\arch.rootfs.tar.gz].
####> Creating distribution [docker]...
####> Running initialization script [configure.sh] on distribution [docker]...
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

```bash
function RunDockerInWsl {
  # Take $Env:DOCKER_WSL or 'docker' if undefined
  $DockerWSL = if ($null -eq $Env:DOCKER_WSL) { "docker" } else { $Env:DOCKER_WSL }
  # Try to find an existing distribution with the name
  $existing = Get-WslInstance $DockerWSL

  # Ensure docker is started
  wsl.exe -d $existing.Name /bin/sh "-c" "test -f /var/run/docker.pid || sudo -b sh -c 'dockerd -p /var/run/docker.pid -H unix:// >/var/log/docker.log 2>&1'"
  # Perform the requested command
  wsl.exe -d $existing.Name /usr/bin/docker $Args
}

Set-Alias -Name docker -Value RunDockerInWsl
```

and run docker directly from powershell:

```bash
❯ docker run --rm -it alpine:latest /bin/sh
Unable to find image 'alpine:latest' locally
latest: Pulling from library/alpine
c158987b0551: Pull complete
Digest: sha256:8914eb54f968791faf6a8638949e480fef81e697984fba772b3976835194c6d4
Status: Downloaded newer image for alpine:latest
/ # exit
❯
```

You can save the distribution image for reuse:

```bash
❯ Export-WslInstance docker
####> Exporting WSL distribution docker to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\docker.Image.tar...
####> Compressing C:\Users\AntoineMartin\AppData\Local\Wsl\Image\docker.Image.tar to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\docker.rootfs.tar.gz...                                                                                                                                   ####> Distribution docker saved to C:\Users\AntoineMartin\AppData\Local\Wsl\Image\docker.rootfs.tar.gz
❯
```

And then create another distribution in the same state from the exported root
filesystem:

```bash
❯ New-WslInstance docker2 -From docker
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\docker2]...                                                                                                                                                                                                                   ####> Creating distribution [docker2]...                                                                                                                                                                                                                                                         ####> Done. Command to enter distribution: wsl -d docker2
```

You can then flip between the two distributions:

```bash
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
