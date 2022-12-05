#!/bin/bash
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


FQDN="archbase"
TIMEZONE="Europe/Paris"
COUNTRY="fr"
LANGUAGE="en_US.UTF-8"
YAY_VERSION="11.1.2"


# Set timezone

rm -f /etc/localtime
/usr/bin/ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

curl -Ls "https://www.archlinux.org/mirrorlist/?country=FR&protocol=https&use_mirror_status=on" | sed -e 's/^#Server/Server/' -e '/^#/d' >/etc/pacman.d/mirrorlist.new
if [ -s /etc/pacman.d/mirrorlist.new ]; then

    if [ ! -f /etc/pacman.d/mirrorlist.orig ]; then
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
    fi
    mv /etc/pacman.d/mirrorlist.new /etc/pacman.d/mirrorlist
else
    echo "Fetched pacman was empty"
    rm -f /etc/pacman.d/mirrorlist.new
fi

if ! grep -q "^${LANGUAGE}" /etc/locale.gen; then
    echo "LANG=${LANGUAGE}" >/etc/locale.conf
    /usr/bin/sed -i "s/#${LANGUAGE}/${LANGUAGE}/" /etc/locale.gen
    /usr/bin/locale-gen
fi

pacman-key --init
pacman-key --populate archlinux
pacman -Sy --noconfirm archlinux-keyring
pacman -Syu --noconfirm
pacman -S --needed --noconfirm zsh git sudo iproute2 gnupg socat openssh

# Install yay. It doesn't work as it complains about systemd
if [ ! -f /usr/local/bin/yay ]; then
    curl -sLo /tmp/yay.tar.gz "https://github.com/Jguer/yay/releases/download/v${YAY_VERSION}/yay_${YAY_VERSION}_x86_64.tar.gz"
    (cd /tmp; tar zxf yay.tar.gz)
    mv "/tmp/yay_${YAY_VERSION}_x86_64/yay" /usr/local/bin/yay
fi

sed -ie '/^root:/ s#:/bin/.*$#:/bin/zsh#' /etc/passwd

if ! [ -d /usr/share/oh-my-zsh ]; then
    git clone --depth 1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh
    sed -i -e 's#^export ZSH=.*#export ZSH=/usr/share/oh-my-zsh#g' /usr/share/oh-my-zsh/templates/zshrc.zsh-template

    # Install ZSH pimp tools
    P10K_DIR="/usr/share/oh-my-zsh/custom/themes/powerlevel10k"
    [ -d "$P10K_DIR" ] || git clone --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
    ATSG_DIR="/usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions"
    [ -d "$ATSG_DIR" ] || git clone --depth=1  https://github.com/zsh-users/zsh-autosuggestions "$ATSG_DIR"
    SSHPGT_DIR="/usr/share/oh-my-zsh/custom/plugins/wsl2-ssh-pageant"
    [ -d "$SSHPGT_DIR" ] || git clone --depth 1 https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin "$SSHPGT_DIR"

    sed -ie '/^plugins=/ s#.*#plugins=(git zsh-autosuggestions wsl2-ssh-pageant)#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template
    sed -ie '/^ZSH_THEME=/ s#.*#ZSH_THEME="powerlevel10k/powerlevel10k"#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template
    echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> /usr/share/oh-my-zsh/templates/zshrc.zsh-template
fi


# Add Oh-My-Zsh to root
install -m 700 /usr/share/oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc
install -m 740 ./p10k.zsh /root/.p10k.zsh
install -d -m 700 /root/.ssh
# Initialize gnupg
gpg -k

username="arch"
if ! getent passwd $username; then
    touch /etc/subuid
    touch /etc/subgid
    /usr/bin/useradd --comment 'Arch User' --create-home --user-group --uid 1000 --shell /bin/zsh --non-unique $username
    /usr/bin/usermod --groups adm,wheel $username
    echo 'Defaults env_keep += "SSH_AUTH_SOCK"' >/etc/sudoers.d/10_$username
    echo "$username ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/10_$username
    /usr/bin/chmod 0440 /etc/sudoers.d/10_$username
    /usr/bin/install -m 700 -o $username -g $username /usr/share/oh-my-zsh/templates/zshrc.zsh-template /home/$username/.zshrc
    /usr/bin/install -m 740 -o $username -g $username ./p10k.zsh /home/$username/.p10k.zsh
    /usr/bin/install --directory --owner=$username --group=$username --mode=0700 /home/$username/.ssh
    su -l $username -c "gpg -k"
fi

touch /etc/wsl-configured
