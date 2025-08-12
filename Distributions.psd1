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
        Username = 'root'
        Uid = 0
    }
    Alpine   = @{
        Name    = 'Alpine'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/alpine-base#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = '3.22'
        Configured = $false
        Username = 'root'
        Uid = 0
    }
    Ubuntu   = @{
        Name    = 'Ubuntu'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/ubuntu-base#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'noble'
        Configured = $false
        Username = 'root'
        Uid = 0
    }
    Debian   = @{
        Name    = 'Debian'
        # This is the root fs used to produce the official Debian slim docker image
        # see https://github.com/docker-library/official-images/blob/master/library/debian
        # see https://github.com/debuerreotype/docker-debian-artifacts
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/debian-base#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'trixie'
        Configured = $false
        Username = 'root'
        Uid = 0
    }
    OpenSuse = @{
        Name    = 'OpenSuse'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/opensuse-base#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'tumbleweed'
        Configured = $false
        Username = 'root'
        Uid = 0
    }

    # Configured distributions (pre-configured/miniwsl)
    ArchConfigured     = @{
        Name    = 'Arch'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/arch#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'current'
        Configured = $true
        Username = 'arch'
        Uid = 1000
    }
    AlpineConfigured   = @{
        Name    = 'Alpine'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/alpine#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = '3.22'
        Configured = $true
        Username = 'alpine'
        Uid = 1000
    }
    UbuntuConfigured   = @{
        Name    = 'Ubuntu'
        Url     = 'docker://ghcr.io/antoinemartin/powershell-wsl-manager/ubuntu#latest'
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'noble'
        Configured = $true
        Username = 'ubuntu'
        Uid = 1000
    }
    DebianConfigured   = @{
        Name    = 'Debian'
        Url     = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/debian#latest"
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'trixie'
        Configured = $true
        Username = 'debian'
        Uid = 1000
    }
    OpenSuseConfigured = @{
        Name    = 'OpenSuse'
        Url     = "docker://ghcr.io/antoinemartin/powershell-wsl-manager/opensuse#latest"
        Hash    = @{
            Type      = 'docker'
        }
        Release = 'tumbleweed'
        Configured = $true
        Username = 'opensuse'
        Uid = 1000
    }
}
