---
title: Development
layout: default
permalink: /development
nav_order: 5
---

<!-- markdownlint-disable MD033 -->
<details open markdown="block">
  <summary>Table of contents</summary>{: .text-delta }
- TOC
{:toc}
</details>
<!-- markdownlint-enable MD033 -->

## Pre-requisites

To modify the module, you will need [git]. You can use [scoop] to install it.
Scoop will also allow you to install [vscode] that is the preferred development
envinronment.

## Getting started

To modify the module, first fork it on github and in clone your copy in your
local modules directory:

```powershell
❯ New-Item -Path $env:USERPROFILE\Documents\WindowsPowerShell\Modules -Force | Out-Null
❯ cd $env:USERPROFILE\Documents\WindowsPowerShell\Modules\
❯ git clone https://github.com/<yourusername>/PowerShell-Wsl-Manager Wsl-Manager
```

The source code of the module is located in the `Wsl-Manager.psm1` file. After a
modification, you need to ensure that the previous version is not loaded in
memory by unloading the module with:

```powershell
❯ Remove-Module Wsl-Manager
❯
```

The loading of the new version is done automatically.

## Adding a new Exported cmdlet

To add a new cmdlet, you need to first create the function in
`Wsl-Manager.psm1`:

```powershell

function <approved_verb>-Wsl {
    <#
    .SYNOPSIS
    ...
    #>
    [CmdletBinding()]
    param(
        ...
    )
}
```

PowerShell is picky about cmdlet verbs. The list is available
[here](https://learn.microsoft.com/en-us/powershell/scripting/developer/cmdlet/approved-verbs-for-windows-powershell-commands?view=powershell-7.3).

Then at the end of the file, export the function:

```powershell
Export-ModuleMember <approved_verb>-Wsl
```

You also need to add the cmdlet to the `FunctionsToExport` property of the
hastable in the `Wsl-Manager.psd1` file:

```powershell
    FunctionsToExport = @("Install-Wsl", "Uninstall-Wsl", "Export-Wsl", "Get-WslRootFS", "Get-Wsl", "Invoke-Wsl", "<approved_verb>-Wsl")
```

Then by removing the module, you are able to test the cmdlet:

```powershell
❯ Remove-Module Wsl-Manager
❯ <approved_verb>-Wsl ...
```

## Adding a new named distro

Adding a named distro involves the following steps:

- Adding the URL of the root filesystem to the `$distributions` hashtable of the
  `Wsl-Manager.psm1` file.
- Testing the installation of the root filesystem without configuration.
- Adapt and/or test the `configure.sh` script for the new distribution.
- Test the installation with local configuration.
- Add the distribution to the `.github\workflows\build_custom_rootfs.yaml` file.
- Build the already configured root filesystem through Github Actions and
  publish it.
- Add the URL of the configured root filesystem to the `$distributions`
  hashtable of the `Wsl-Manager.psm1` file.
- Test the installation of the already configured root filesystem.

The following details each step for [OpenSuse](https://www.opensuse.org/).
OpenSuse is a RPM based distribution close to RHEL. A rolling release version of
the distribution is available under the name
[Tumbleweed](https://www.opensuse.org/#Tumbleweed).

### Adding the URL

The rootfs URL we find is the following:

```text
https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz
```

In the `Wsl-Manager.psm1` file, at the top of the file, the `$distributions`
hastable defines the root filesystem urls for each distribution. add an entry
with the name `OpenSuse` and the above URL:

```powershell
$distributions = @{
    ...
    OpenSuse = @{
        Url             = 'https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz'
    }
}
```

### Testing the installion of the root filesystem

We can test the installation of the root filesystem with the following:

```console
PS> Remove-Module Wsl-Manager
PS> install-wsl suse -Distribution OpenSuse -SkipConfigure
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\suse]...
####> Downloading https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\opensuse.rootfs.tar.gz...
####> Creating distribution [suse]...
####> Done. Command to enter distribution: wsl -d suse
PS> wsl -d suse
LAPTOP-VKHDD5JR:/mnt/c/Users/AntoineMartin/Documents/WindowsPowerShell/Modules/Wsl-Manager # id
uid=0(root) gid=0(root) groups=0(root)
LAPTOP-VKHDD5JR:/mnt/c/Users/AntoineMartin/Documents/WindowsPowerShell/Modules/Wsl-Manager # exit
logout
PS>
```

### Adapt and test the configure script

The `configure.sh` script configures the system. It identifies the Linux flavor
by looking at the `ID` variable in the `/etc/os-release` script:

```bash
PS> wsl -d suse cat /etc/os-release
NAME="openSUSE Tumbleweed"
# VERSION="20221215"
ID="opensuse-tumbleweed"
...
PS>
```

Here it will use `opensuse` as the os name as well as the name for the default
user to create.

The script tries to call a `configure_suse()` function. Let's create one in the
script:

```bash

configure_opensuse() {
  echo "Hello from Tumbleweed..."
}
```

{: .highlight }

As the script may be run through bash in posix mode (debian), dash or ash
(alpine), you should stick to good old Bourne Again Shell syntax (POSIX) as much
as possible.

We can now invoke the script:

```console
PS> cd $env:USERPROFILE\Documents\WindowsPowerShell\Modules\Wsl-Manager
PS> wsl -d suse -u root ./configure.sh
We are on opensuse
Hello from Tumbleweed...
Configuration done.
PS>
```

When the configuration has been performed without errors, the `configure.sh`
script creates a file named `/etc/wsl-configured` to prevent re-configuration in
case the WSL distribution is [exported](./usage/command-reference#export-wsl).

Running the configuration again doesn't work:

```console
PS> wsl -d suse -u root ./configure.sh
Already configured
PS>
```

However, deleting the file `/etc/wsl-configured` allows re-running the
configuration again:

```console
PS> wsl -d suse -u root rm /etc/wsl-configured
PS> wsl -d suse -u root ./configure.sh
We are on opensuse
Hello from Tumbleweed...
Configuration done.
PS>
```

Now this is a matter of completing the `configure_opensuse()` method in order to
perform the configuration.

OpenSuse is a RPM based distribution similar to RHEL. The configuration script
already contains a function `configure_rhel_like()` to configure such systems.
The main difference between Suse and the RHEL based distributions is the use of
`dnf` as the package manager. `dnf` is a fork of `yum` and is command line
compatible. Instead of copy/pasting `configure_rhel_like()` to create
`configure_opensuse()`, we can adapt `configure_rhel_like()` to take the name of
the package manager as argument.:

```diff
diff --git a/configure.sh b/configure.sh
index f622a5d..87d3c2e 100644
--- a/configure.sh
+++ b/configure.sh
@@ -269,7 +269,8 @@ configure_arch() {

 # Configure a RHEL like system (CentOS, Almalinux, ...)
 #
-# @param $1 list of groups separated by commas of the groups to add to the sudo
+# @param $1 the name of the package manager (yum, dnf)
+# @param $2 list of groups separated by commas of the groups to add to the sudo
 #           user. The administrative groups may differ from distribution to
 #           distribution (staff, wheel, admin).
 # @param $@ list of additionnal packages to add.
@@ -283,14 +284,16 @@ configure_arch() {
 # - Add a sudo user derived from the name of the distribution with the
 #   appropriate configuration and groups
 configure_rhel_like() {
+    local pkmgr=$1
+    shift
     local admin_group_name=$1
     shift
     local additional_packages="$@"

     echo "Adding packages..."
-    yum -y -q makecache >/dev/null 2>&1
-    yum -y -q install zsh git sudo gnupg socat openssh-clients tar $additional_packages >/dev/null 2>&1
-    yum -y clean all >/dev/null 2>&1
+    $pkmgr -y -q makecache >/dev/null 2>&1
+    $pkmgr -y -q install zsh git sudo gnupg socat openssh-clients tar $additional_packages >/dev/null 2>&1
+    $pkmgr -y clean all >/dev/null 2>&1

     change_root_shell
```

Then we need to adapt the already existing `configure_...()` functions in order
to pass `yum` as argument:

```diff
@@ -304,22 +307,31 @@ configure_rhel_like() {
 # Configure an Alma Linux System
 # @ see configure_rhel_like
 configure_almalinux() {
-    configure_rhel_like adm,wheel
+    configure_rhel_like yum adm,wheel
 }

 # Configure a Rocky Linux System
 # @ see configure_rhel_like
 configure_rocky() {
-    configure_rhel_like adm,wheel
+    configure_rhel_like yum adm,wheel
 }

 # Configure a CentOS Linux System
 # @ see configure_rhel_like
 configure_centos() {
-    configure_rhel_like adm,wheel
+    configure_rhel_like yum adm,wheel
 }
```

And then through trial and error, we find the following peculiarities to Suse:

- The _admin_ group seems to be `trusted`
- The `curl` and `gzip` commands are not present on the base system and need to
  be installed.
- `dnf` is slow must
  [can be made faster](https://ostechnix.com/how-to-speed-up-dnf-package-manager-in-fedora/).

We end up with the following `configure_opensuse()` command:

```diff
+# Configure an OpenSuse Linux System
+# @ see configure_rhel_like
+configure_opensuse() {
+    echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
+    echo "fastestmirror=True" >> /etc/dnf/dnf.conf
+
+    configure_rhel_like dnf trusted curl gzip
+}
+
 username=$(cat /etc/os-release | grep ^ID= | cut -d= -f 2 | tr -d '"' | cut -d"-" -f 1)
 if [ -z "$username" ]; then
     echo "Can't find distribution flavor"
```

{: .important }

> When a error occurs on gitstatus initialization, executing the following is
> useful for debugging:
>
> ```console
> PS> wsl -d suse -u root sh -c "echo GITSTATUS_LOG_LEVEL=DEBUG >> ~/.zshrc"
> ```

The full test cycle is the following:

```console
PS> Uninstall-Wsl suse
PS> Install-Wsl suse -Distribution OpenSuse -SkipConfigure
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\suse]...
####> OpenSuse Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\opensuse.rootfs.tar.gz].
####> Creating distribution [suse]...
####> Done. Command to enter distribution: wsl -d suse
PS> wsl -d suse -u root ./configure.sh
We are on opensuse
Adding packages...
Change root shell to zsh
Adding oh-my-zsh...
Configuring root home directory /root...
Configuring user opensuse...
Group 'mail' not found. Creating the user mailbox file with 0600 mode.
Configuring opensuse home directory /home/opensuse...
Configuration done.
PS> wsl -d suse -u opensuse
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(opensuse) gid=1000(opensuse) groups=1000(opensuse),42(trusted)
❯ exit
PS>
```

And then finally the same without `-SkipConfigure`:

```console
PS> Uninstall-Wsl suse
PS> Install-Wsl suse -Distribution OpenSuse
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\suse]...
####> OpenSuse Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\opensuse.rootfs.tar.gz].
####> Creating distribution [suse]...
####> Running initialization script [configure.sh] on distribution [suse]...
####> Done. Command to enter distribution: wsl -d suse
PS> wsl -d suse
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(opensuse) gid=1000(opensuse) groups=1000(opensuse),42(trusted)
❯ exit
PS>
```

### Add the building of the distribution to github actions

You need to add the new flavor to the matrix strategy in
`.github/workflows/build_custom_rootfs.yaml`:

```diff
diff --git a/.github/workflows/build_custom_rootfs.yaml b/.github/workflows/build_custom_rootfs.yaml
index a25c86b..926d4c4 100644
--- a/.github/workflows/build_custom_rootfs.yaml
+++ b/.github/workflows/build_custom_rootfs.yaml
@@ -23,7 +23,7 @@ jobs:
     runs-on: ubuntu-latest
     strategy:
       matrix:
-        flavor: [ ubuntu, arch, alpine ]
+        flavor: [ ubuntu, arch, alpine, opensuse]
         include:
           - flavor: ubuntu
             base_url: https://cloud-images.ubuntu.com/wsl/noble/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz
@@ -31,6 +31,8 @@ jobs:
             base_url: https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/2024.04.01/archlinux.rootfs.tar.gz
           - flavor: alpine
             base_url: https://dl-cdn.alpinelinux.org/alpine/v3.19/releases/x86_64/alpine-minirootfs-3.19.1-x86_64.tar.gz
+          - flavor: opensuse
+            base_url: https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz
     steps:
       - uses: actions/checkout@v3

@@ -80,3 +82,5 @@ jobs:
             arch-rootfs/miniwsl.arch.rootfs.tar.gz.sha256
             alpine-rootfs/miniwsl.alpine.rootfs.tar.gz
             alpine-rootfs/miniwsl.alpine.rootfs.tar.gz.sha256
+            opensuse-rootfs/miniwsl.opensuse.rootfs.tar.gz
+            opensuse-rootfs/miniwsl.opensuse.rootfs.tar.gz.sha256
```

The URL is the URL that has been added to `Wsl-Manager.psm1` previously.

At this point, the code modifications can be pushed to a branch in your github
fork.

### Test the Github actions building of the configured distribution

The generation of the configured images needs to be triggered manually your fork
interface:

![](./assets/github_actions.png)

Then if you go on the `releases/tag/latest` page, you will see the distribution.

![](./assets/releases.png)

### Add the URL of configured filesystem to the module

You can add the URL of the generated distribution in the `$distributions`
hashtable of the `Wsl-Manager.psm1` source file:

```diff
diff --git a/Wsl-Manager.psm1 b/Wsl-Manager.psm1                                                                                                                                                                                                                                                 index 3edeca0..165c6f0 100644                                                                                                                                                                                                                                                                    --- a/Wsl-Manager.psm1
+++ b/Wsl-Manager.psm1
@@ -39,6 +39,7 @@ $distributions = @{
     }
     OpenSuse = @{
         Url = "https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz"
+        ConfiguredUrl = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.opensuse.rootfs.tar.gz"
     }
 }
```

### Test the installation of the already configured filesystem

You can now test the newly created distribution:

```console
PS> Remove-Module wsl-manager
PS> Uninstall-Wsl suse
PS> Install-Wsl suse -Distribution OpenSuse -Configured
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\suse]...
####> Downloading https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/download/latest/miniwsl.opensuse.rootfs.tar.gz => C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.opensuse.rootfs.tar.gz...
####> Creating distribution [suse]...
####> Running initialization script [configure.sh] on distribution [suse]...
####> Done. Command to enter distribution: wsl -d suse
PS> wsl -d suse
[powerlevel10k] fetching gitstatusd .. [ok]
❯ id
uid=1000(opensuse) gid=1000(opensuse) groups=1000(opensuse),42(trusted)
❯ exit
PS>
```

You can now commit your modifications and make a pull request :+1: :smile:.

[git]: https://git-scm.com/download/win
[scoop]: https://scoop.sh/
[vscode]: https://code.visualstudio.com/
