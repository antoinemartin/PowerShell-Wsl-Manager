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
    # Unconfigured distributions (vanilla/stock)
    Arch     = @{
        Name    = 'Arch'
        Url     = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/archlinux.rootfs.tar.gz'
        Hash    = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = 'current'
        Configured = $false
    }
    Alpine   = @{
        Name    = 'Alpine'
        Url     = 'https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.1-x86_64.tar.gz'
        Hash    = @{
            Url       = 'https://dl-cdn.alpinelinux.org/alpine/v3.22/releases/x86_64/alpine-minirootfs-3.22.1-x86_64.tar.gz.sha256'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = '3.22'
        Configured = $false
    }
    Ubuntu   = @{
        Name    = 'Ubuntu'
        Url     = 'https://cloud-images.ubuntu.com/wsl/noble/current/ubuntu-noble-wsl-amd64-wsl.rootfs.tar.gz'
        Hash    = @{
            Url       = 'https://cloud-images.ubuntu.com/wsl/noble/current/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = 'noble'
        Configured = $false
    }
    Debian   = @{
        Name    = 'Debian'
        # This is the root fs used to produce the official Debian slim docker image
        # see https://github.com/docker-library/official-images/blob/master/library/debian
        # see https://github.com/debuerreotype/docker-debian-artifacts
        Url     = "https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/stable/rootfs.tar.xz"
        Hash    = @{
            Url       = 'https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/stable/rootfs.tar.xz.sha256'
            Algorithm = 'SHA256'
            Type      = 'single'
        }
        Release = 'bookworm'
        Configured = $false
    }
    OpenSuse = @{
        Name    = 'OpenSuse'
        Url     = "https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz"
        Hash    = @{
            Url       = 'https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz.sha256'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = 'tumbleweed'
        Configured = $false
    }

    # Configured distributions (pre-configured/miniwsl)
    ArchConfigured     = @{
        Name    = 'Arch'
        Url     = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.arch.rootfs.tar.gz'
        Hash    = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = 'current'
        Configured = $true
    }
    AlpineConfigured   = @{
        Name    = 'Alpine'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-alpine#3.22.1'
        Hash    = @{
            Url       = 'docker://ghcr.io'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = '3.22'
        Configured = $true
    }
    UbuntuConfigured   = @{
        Name    = 'Ubuntu'
        Url     = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.ubuntu.rootfs.tar.gz'
        Hash    = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = 'noble'
        Configured = $true
    }
    DebianConfigured   = @{
        Name    = 'Debian'
        Url     = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.debian.rootfs.tar.gz"
        Hash    = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = 'bookworm'
        Configured = $true
    }
    OpenSuseConfigured = @{
        Name    = 'OpenSuse'
        Url     = "https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/miniwsl.opensuse.rootfs.tar.gz"
        Hash    = @{
            Url       = 'https://github.com/antoinemartin/PowerShell-Wsl-Manager/releases/latest/download/SHA256SUMS'
            Algorithm = 'SHA256'
            Type      = 'sums'
        }
        Release = 'tumbleweed'
        Configured = $true
    }
}
