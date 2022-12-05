#!/bin/sh
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

# Fail on error
set -euxo pipefail

if [ -f /etc/wsl-configured ]; then
    exit 0
fi

# Add Edge APK repo and basic dependencies
grep -q edge /etc/apk/repositories || echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories
apk update
apk add zsh oh-my-zsh tzdata git libstdc++ doas iproute2 gnupg socat openssh openrc

# Set timezone
cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
echo "Europe/Paris" >/etc/timezone

# Change root default shell to ZSH
sed -ie '/^root:/ s#:/bin/.*$#:/bin/zsh#' /etc/passwd

# Install ZSH pimp tools
P10K_DIR="/usr/share/oh-my-zsh/custom/themes/powerlevel10k"
[ -d "$P10K_DIR" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
ATSG_DIR="/usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions"
[ -d "$ATSG_DIR" ] || git clone --depth=1  https://github.com/zsh-users/zsh-autosuggestions "$ATSG_DIR"
SSHPGT_DIR="/usr/share/oh-my-zsh/custom/plugins/wsl2-ssh-pageant"
[ -d "$SSHPGT_DIR" ] || git clone --depth 1 https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin "$SSHPGT_DIR"

sed -ie '/^plugins=/ s#.*#plugins=(git zsh-autosuggestions wsl2-ssh-pageant)#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template
sed -ie '/^ZSH_THEME=/ s#.*#ZSH_THEME="powerlevel10k/powerlevel10k"#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template

# Add Oh-My-Zsh to root
install -m 700 /usr/share/oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc
install -m 740 ./p10k.zsh /root/.p10k.zsh
install -d -m 700 /root/.ssh
grep -q p10k.zsh /root/.zshrc || echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> /root/.zshrc
# Initialize gnupg
gpg -k

username="alpine"
if ! getent passwd $username; then
    adduser -s /bin/zsh -g $username -D $username
    addgroup $username wheel
    echo "permit nopass keepenv :wheel" >> /etc/doas.d/doas.conf
    install -m 700 -o $username -g $username /usr/share/oh-my-zsh/templates/zshrc.zsh-template /home/$username/.zshrc
    install -m 740 -o $username -g $username ./p10k.zsh /home/$username/.p10k.zsh
    echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> /home/$username/.zshrc
    install -m 700 -o $username -g $username -d /home/$username/.ssh
    su -l $username -c "gpg -k"
fi

# OPENRC Stuff
# With the following, openrc can be started on the distribution with
# > doas openrc default
# It helps when installing crio, docker, kubernetes, ...
if ! [ -d /lib/rc/init.d ]; then
    mkdir -p /lib/rc/init.d
    ln -s /lib/rc/init.d /run/openrc || /bin/true
    touch /lib/rc/init.d/softlevel
    [ -f /etc/rc.conf.orig ] || mv /etc/rc.conf /etc/rc.conf.orig
    cat - > /etc/rc.conf <<EOF2
rc_sys="prefix"
rc_controller_cgroups="NO"
rc_depend_strict="NO"
rc_need="!net !dev !udev-mount !sysfs !checkfs !fsck !netmount !logger !clock !modules"
EOF2
fi

touch /etc/wsl-configured
