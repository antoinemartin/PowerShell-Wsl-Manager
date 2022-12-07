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

apt update -qq
apt install -qq -y zsh git sudo iproute2 gnupg socat openssh-client
apt-get clean

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
/usr/bin/install -m 700 /usr/share/oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc
/usr/bin/install -m 740 ./p10k.zsh /root/.p10k.zsh
/usr/bin/install -d -m 700 /root/.ssh
# Initialize gnupg
gpg -k

username="ubuntu"
if ! getent passwd $username; then
    /usr/sbin/useradd --comment '$username User' --create-home --user-group --uid 1000 --shell /bin/zsh --non-unique $username
    /usr/sbin/usermod --groups admin $username
    echo 'Defaults env_keep += "SSH_AUTH_SOCK"' >/etc/sudoers.d/10_$username
    echo "$username ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/10_$username
    /usr/bin/chmod 0440 /etc/sudoers.d/10_$username
    /usr/bin/install -m 700 -o $username -g $username /usr/share/oh-my-zsh/templates/zshrc.zsh-template /home/$username/.zshrc
    /usr/bin/install -m 740 -o $username -g $username ./p10k.zsh /home/$username/.p10k.zsh
    /usr/bin/install --directory --owner=$username --group=$username --mode=0700 /home/$username/.ssh
    /usr/bin/su -l $username -c "gpg -k"
fi

touch /etc/wsl-configured
