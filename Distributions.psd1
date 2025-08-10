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
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch-base#latest'
        Hash    = @{
            Type      = 'docker'
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
        Url     = 'https://cdimages.ubuntu.com/ubuntu-wsl/noble/daily-live/current/noble-wsl-amd64.wsl'
        Hash    = @{
            Url       = 'https://cdimages.ubuntu.com/ubuntu-wsl/noble/daily-live/current/SHA256SUMS'
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
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-arch#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'current'
        Configured = $true
    }
    AlpineConfigured   = @{
        Name    = 'Alpine'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-alpine#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = '3.22'
        Configured = $true
    }
    UbuntuConfigured   = @{
        Name    = 'Ubuntu'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-ubuntu#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'noble'
        Configured = $true
    }
    DebianConfigured   = @{
        Name    = 'Debian'
        Url     = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-debian#latest"
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'bookworm'
        Configured = $true
    }
    OpenSuseConfigured = @{
        Name    = 'OpenSuse'
        Url     = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-opensuse#latest"
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'tumbleweed'
        Configured = $true
    }
}
