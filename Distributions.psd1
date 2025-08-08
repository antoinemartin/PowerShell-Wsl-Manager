# Copyright 2022 Antoine Martin
# 
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
# 
#     http://www.apache.org/licenses/LICENSE-2.0
# 
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# WSL Root Filesystem Distributions Configuration
# This file contains the configuration for built-in distributions

@{
    Arch     = @{
        Url            = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/archlinux.rootfs.tar.gz'
        Hash           = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        ConfiguredUrl  = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.arch.rootfs.tar.gz'
        ConfiguredHash = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release        = 'current'
    }
    Alpine   = @{
        Url            = 'https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.1-x86_64.tar.gz'
        Hash           = @{
            Url       = 'https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.1-x86_64.tar.gz.sha256'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        ConfiguredUrl  = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-alpine#3.22.1'
        ConfiguredHash = @{
            Url       = 'docker://ghcr.io'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release        = '3.22'
    }
    Ubuntu   = @{
        Url            = 'https://cloud-images.ubuntu.com/wsl/noble/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'
        Hash           = @{
            Url       = 'https://cloud-images.ubuntu.com/wsl/noble/current/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        ConfiguredUrl  = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.ubuntu.rootfs.tar.gz'
        ConfiguredHash = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release        = 'noble'
    }
    Debian   = @{
        # This is the root fs used to produce the official Debian slim docker image
        # see https://github.com/docker-library/official-images/blob/master/library/debian
        # see https://github.com/debuerreotype/docker-debian-artifacts
        Url            = "https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/stable/rootfs.tar.xz"
        Hash           = @{
            Url       = 'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/stable/rootfs.tar.xz.sha256'
            Algorithm = 'SHA256'
            Type      = 'single'
        }
        ConfiguredUrl  = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.debian.rootfs.tar.gz"
        ConfiguredHash = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release        = 'bookworm'
    }
    OpenSuse = @{
        Url            = "https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz"
        Hash           = @{
            Url       = 'https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz.sha256'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        ConfiguredUrl  = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.opensuse.rootfs.tar.gz"
        ConfiguredHash = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release        = 'tumbleweed'
    }
}
