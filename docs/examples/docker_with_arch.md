---
description: |
  Set up an Arch Linux WSL instance as a lightweight alternative to Docker Desktop for container development on Windows.
---

You can create an Instance for building docker images. We will use Arch for this
example.

## Installation

First install the distribution:

```ps1con
PS>  New-WslInstance docker -From arch
⌛ Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\docker]...
⌛ Creating instance [docker] from [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\docker.arch.rootfs.tar.gz]...
🎉 Done. Command to enter instance: Invoke-WslInstance -In docker or wsl -d docker

Name                                        State Version Default
----                                        ----- ------- -------
docker                                    Stopped       2   False

PS>
```

Connect to it as root and install docker:

```ps1con
PS> # Add docker to the distribution
PS> iwsl -In docker -User root pacman -Sy --noconfirm --needed docker
:: Synchronizing package databases...
 core is up to date
 extra                                         7.8 MiB  42.3 MiB/s 00:00 [########################################] 100%
 ...(omitted for brevity)...
 (4/4) Arming ConditionNeedsUpdate...

 PS>
```

Add the `arch` user to the docker group:

```ps1con
PS> # Adding base user as docker
PS> iwsl -In docker -User root usermod -aG docker arch
```

## Use WSL docker client from Windows

With this method, When you type `docker` in Windows, it actually executes the
docker client in the `docker` WSL instance.

In order to do that, you need to define an alias on Windows. This is done by
adding the following to
`$Env:USERPROFILE\Documents\WindowsPowerShell\Microsoft.PowerShell_profile.ps1.ps1`
(`$PROFILE` variable):

??? sample "docker_profile.ps1"

    The `Add-DockerProfile.ps1` script adds the contents of the
    `docker_profile.ps1` file to your Powershell profile.

    === ":octicons-file-code-16: docker_profile.ps1"

        ```powershell
        --8<-- "docs/examples/docker_profile.ps1"
        ```

    === ":octicons-terminal-16: Add-DockerProfile.ps1"

        ```powershell
        --8<-- "docs/examples/Add-DockerProfile.ps1"
        ```

Once you open a new powershell window, you can run docker and run docker
directly from powershell:

```ps1con
PS> docker run --rm -it alpine:latest /bin/sh
Unable to find image 'alpine:latest' locally
latest: Pulling from library/alpine
c158987b0551: Pull complete
Digest: sha256:8914eb54f968791faf6a8638949e480fef81e697984fba772b3976835194c6d4
Status: Downloaded newer image for alpine:latest
/ # exit
PS>
```

The `docker` alias starts docker automatically if it's not already running.

You can stop docker with:

```powershell
PS> Stop-WslDocker
```

You can save the instance as an image for reuse:

```ps1con
PS> Export-WslInstance docker
...
PS>
```

And then create another distribution in the same state from the exported root
filesystem:

```ps1con
PS> New-WslInstance docker2 -From docker
...
```

!!! warning "Only one WSL instance can be active at a time"

    Only one docker daemon can be active at a time. This is because docker
    creates virtual network interfaces, `docker0` in particular.
    As the network interface namespace is shared between WSL instances, this
    creates collisions.

You can then flip between the two distributions:

```ps1con
# Run nginx in docker distribution
❯ docker run '-d' '-p' 8080:80 '--name' nginx nginx:latest
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
PS> docker ps
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         PORTS                                   NAMES
61f5993c6e1a   nginx:latest   "/docker-entrypoint.…"   7 seconds ago   Up 6 seconds   0.0.0.0:8080->80/tcp, :::8080->80/tcp   nginx
PS> # Switch to other instance
PS> Stop-WslDocker; $env:DOCKER_WSL="docker2"; Start-WslDocker
# Clean docker instance !
PS> docker ps '-a'
CONTAINER ID   IMAGE     COMMAND   CREATED   STATUS    PORTS     NAMES
```

## Use Windows docker client on Windows

While the above solution works well, you may also want to use the Windows docker
client directly from Windows. This can be done by configuring the Windows docker
client to communicate with the WSL docker daemon.

To do this, you need to set the `DOCKER_HOST` environment variable in your
Windows PowerShell profile to point to the WSL docker daemon. You can add the
following line to your PowerShell profile:

```powershell
$env:DOCKER_HOST="tcp://localhost:2376"
```

After adding this line, you can use the Windows docker client as you normally
would, and it will communicate with the WSL docker daemon.

If you are using scoop, you can add the docker client to Windows with:

```ps1con
PS> scoop install docker
```

if you have installed the docker alias in your profile, you need to remove it:

```ps1con
PS> Remove-Item Alias:docker
```

And then you can use the Windows docker client as you normally would:

```ps1con
PS> # Quoting arguments is not needed anymore
PS> docker ps -a
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS                     PORTS     NAMES
66ada31ac41b   nginx:latest   "/docker-entrypoint.…"   6 minutes ago   Exited (0) 6 minutes ago             nginx
PS> docker restart nginx
nginx
PS> docker ps
CONTAINER ID   IMAGE          COMMAND                  CREATED         STATUS         PORTS                                     NAMES
66ada31ac41b   nginx:latest   "/docker-entrypoint.…"   7 minutes ago   Up 7 seconds   0.0.0.0:8080->80/tcp, [::]:8080->80/tcp   nginx
PS>
```

To remove the alias from your profile, you can use the following command:

```ps1con
PS> (Get-Content $PROFILE | Select-String -Pattern '^Set-Alias -Name docker' -NotMatch | Set-Content $PROFILE
```
