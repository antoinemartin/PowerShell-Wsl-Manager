---
title: Github pages tester with Alpine
layout: default
parent: Examples
---

Create the Alpine distribution:

```powershell
PS> install-wsl jekyll -Distribution Alpine -Configured
####> Creating directory [C:\Users\AntoineMartin\AppData\Local\Wsl\jekyll]...
####> Alpine Root FS already at [C:\Users\AntoineMartin\AppData\Local\Wsl\RootFS\miniwsl.alpine.rootfs.tar.gz].
####> Creating distribution [jekyll]...
####> Done. Command to enter distribution: wsl -d jekyll
PS>
```

As `root`, install ruby, bundler and the tools to compile other Gems:

```powershell
PS> wsl -d jekyll -u root apk add build-base ruby ruby-dev ruby-bundler
fetch https://dl-cdn.alpinelinux.org/alpine/v3.17/main/x86_64/APKINDEX.tar.gz
fetch https://dl-cdn.alpinelinux.org/alpine/v3.17/community/x86_64/APKINDEX.tar.gz
fetch http://dl-cdn.alpinelinux.org/alpine/edge/testing/x86_64/APKINDEX.tar.gz
(1/29) Installing binutils (2.39-r2)
...
(29/29) Installing ruby-dev (3.1.3-r0)
Executing busybox-1.35.0-r29.trigger
OK: 325 MiB in 119 packages
PS>
```

Configure Bundler to install the gems in the user's directory. Otherwise,
Bundler will try to install the gems system wise and generate a permission
error:

```powershell
PS> wsl -d jekyll bundle config set --global path /home/alpine/.gems
```

Install the jekyll and github pages dependencies. The Gemfile is in the docs
directory:

```powershell
PS> cd docs
PS> wsl -d jekyll bundle install
Fetching gem metadata from https://rubygems.org/...........
Resolving dependencies....
Fetching rake 13.0.6
...
PS>
```

Now the development server can be started and accessed. The `--force-polling`
option is needed when the files reside on the Windows filesystem:

```powershell
PS> wsl -d jekyll  bundle exec jekyll serve --livereload --force-polling
Configuration file: /mnt/c/Users/AntoineMartin/Documents/WindowsPowerShell/Modules/Wsl-Manager/docs/_config.yml
To use retry middleware with Faraday v2.0+, install `faraday-retry` gem
            Source: /mnt/c/Users/AntoineMartin/Documents/WindowsPowerShell/Modules/Wsl-Manager/docs
       Destination: /mnt/c/Users/AntoineMartin/Documents/WindowsPowerShell/Modules/Wsl-Manager/docs/_site
 Incremental build: disabled. Enable with --incremental
      Generating...
      Remote Theme: Using theme just-the-docs/just-the-docs
       Jekyll Feed: Generating feed for posts
                    done in 4.137 seconds.
                    Auto-regeneration may not work on some Windows versions.
                    Please see: https://github.com/Microsoft/BashOnWindows/issues/216
                    If it does not work, please upgrade Bash on Windows or run Jekyll with --no-watch.
 Auto-regeneration: enabled for '/mnt/c/Users/AntoineMartin/Documents/WindowsPowerShell/Modules/Wsl-Manager/docs'
LiveReload address: http://127.0.0.1:35729
    Server address: http://127.0.0.1:4000/PowerShell-Wsl-Manager/
  Server running... press ctrl-c to stop.
```
