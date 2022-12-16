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
set -eu

if [ -f /etc/wsl-configured ]; then
    echo "Already configured"
    exit 0
fi


change_root_shell() {
    echo "Change root shell to zsh"
    sed -ie '/^root:/ s#:/bin/.*$#:/bin/zsh#' /etc/passwd
}


add_oh_my_zsh() {

    if ! [ -d /usr/share/oh-my-zsh ]; then
        echo "Adding oh-my-zsh..."
        git clone --quiet --depth 1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh
        sed -i -e 's#^export ZSH=.*#export ZSH=/usr/share/oh-my-zsh#g' /usr/share/oh-my-zsh/templates/zshrc.zsh-template

        # Install ZSH pimp tools
        P10K_DIR="/usr/share/oh-my-zsh/custom/themes/powerlevel10k"
        [ -d "$P10K_DIR" ] || git clone --quiet --depth=1 https://github.com/romkatv/powerlevel10k.git "$P10K_DIR"
        ATSG_DIR="/usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions"
        [ -d "$ATSG_DIR" ] || git clone --quiet --depth=1  https://github.com/zsh-users/zsh-autosuggestions "$ATSG_DIR"
        SSHPGT_DIR="/usr/share/oh-my-zsh/custom/plugins/wsl2-ssh-pageant"
        [ -d "$SSHPGT_DIR" ] || git clone --quiet --depth 1 https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin "$SSHPGT_DIR"

        sed -ie '/^plugins=/ s#.*#plugins=(git zsh-autosuggestions wsl2-ssh-pageant)#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template
        sed -ie '/^ZSH_THEME=/ s#.*#ZSH_THEME="powerlevel10k/powerlevel10k"#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template
        echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> /usr/share/oh-my-zsh/templates/zshrc.zsh-template
    else
        echo "oh-my-zsh already present"
    fi
}


initialize_root_shell() {
    
    if ! [ -f /root/.p10k.zsh ]; then
        echo "Initialize root shell..."
        # Add Oh-My-Zsh to root
        install -m 700 /usr/share/oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc
        install -m 740 ./p10k.zsh /root/.p10k.zsh
        install -d -m 700 /root/.ssh
        # Initialize gnupg
        gpg -k >/dev/null 2>&1
    else
        echo "Root shell already initialized"
    fi
}


initialize_user() {
    install -m 700 -o $username -g $username /usr/share/oh-my-zsh/templates/zshrc.zsh-template /home/$username/.zshrc
    install -m 740 -o $username -g $username ./p10k.zsh /home/$username/.p10k.zsh
    install --directory -o $username -g $username -m 0700 /home/$username/.ssh
    su -l $username -c "gpg -k" >/dev/null 2>&1
}


configure_user_sudo() {
    admin_group_name=$1
    if ! getent passwd $username; then
        echo "Configuring user $username..."
        useradd --comment '$username User' --create-home --user-group --uid 1000 --shell /bin/zsh --non-unique $username
        usermod --groups $admin_group_name $username
        echo 'Defaults env_keep += "SSH_AUTH_SOCK"' >/etc/sudoers.d/10_$username
        echo "$username ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/10_$username
        chmod 0440 /etc/sudoers.d/10_$username
        initialize_user
    else
        echo "User $username already configured"
    fi
}

configure_debian_like() {
    admin_group_name=$1
    shift
    additional_packages="$@"

    echo "Adding packages..."
    apt update -qq >/dev/null 2>&1
    apt-get install -qq -y zsh git sudo iproute2 gnupg socat openssh-client $additional_packages >/dev/null 2>&1
    apt-get clean

    change_root_shell

    add_oh_my_zsh

    initialize_root_shell

    configure_user_sudo $admin_group_name
}

configure_debian() {
    configure_debian_like staff curl
}

configure_ubuntu() {
    configure_debian_like admin
}

configure_alpine() {
    set -o pipefail

    echo "Adding packages..."
    grep -q edge /etc/apk/repositories || echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories
    apk update --quiet
    apk add --quiet --no-progress --no-cache zsh tzdata git libstdc++ doas iproute2 gnupg socat openssh openrc

    # Set timezone
    cp /usr/share/zoneinfo/Europe/Paris /etc/localtime
    echo "Europe/Paris" >/etc/timezone

    change_root_shell

    add_oh_my_zsh

    initialize_root_shell

    if ! getent passwd $username; then
        echo "Configuring user $username..."
        adduser -s /bin/zsh -g $username -D $username
        addgroup $username wheel
        echo "permit nopass keepenv :wheel" >> /etc/doas.d/doas.conf
        initialize_user
    fi

    # OPENRC Stuff
    # With the following, openrc can be started on the distribution with
    # > doas openrc default
    # It helps when installing crio, docker, kubernetes, ...
    if ! [ -d /lib/rc/init.d ]; then
        echo "Configuring OpenRC"
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
}


configure_arch() {
    set -o pipefail

    FQDN="archbase"
    TIMEZONE="Europe/Paris"
    COUNTRY="fr"
    LANGUAGE="en_US.UTF-8"
    YAY_VERSION="11.1.2"

    # Set timezone
    echo "Setting timezone and locale..."
    rm -f /etc/localtime
    /usr/bin/ln -s /usr/share/zoneinfo/${TIMEZONE} /etc/localtime

    if ! grep -q "^${LANGUAGE}" /etc/locale.gen; then
        echo "LANG=${LANGUAGE}" >/etc/locale.conf
        /usr/bin/sed -i "s/#${LANGUAGE}/${LANGUAGE}/" /etc/locale.gen
        /usr/bin/locale-gen >/dev/null 2>&1
    fi

    echo "Initializing pacman..."

    if [ ! -f /etc/pacman.d/mirrorlist.orig ]; then
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
    fi
    echo 'Server = https://mirror.cyberbits.eu/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

    pacman-key --init >/dev/null 2>&1
    pacman-key --populate archlinux  >/dev/null 2>&1
    sed -i -e 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf
    
    echo "Adding packages..."
    pacman -Sy --noconfirm archlinux-keyring >/dev/null 2>&1
    pacman -Syu --noconfirm  >/dev/null 2>&1
    pacman -S --needed --noconfirm zsh git sudo iproute2 gnupg socat openssh  >/dev/null 2>&1
    pacman -Scc --noconfirm  >/dev/null 2>&1
    sed -i -e 's/^#CheckSpace/CheckSpace/' /etc/pacman.conf

    # Install yay. It doesn't work as it complains about systemd
    if [ ! -f /usr/local/bin/yay ]; then
        curl -sLo /tmp/yay.tar.gz "https://github.com/Jguer/yay/releases/download/v${YAY_VERSION}/yay_${YAY_VERSION}_x86_64.tar.gz"
        (cd /tmp; tar zxf yay.tar.gz)
        mv "/tmp/yay_${YAY_VERSION}_x86_64/yay" /usr/local/bin/yay
    fi

    change_root_shell

    add_oh_my_zsh

    initialize_root_shell

    configure_user_sudo adm,wheel
    touch /etc/subuid
    touch /etc/subgid
}


configure_centos_like() {
    admin_group_name=$1
    shift
    additional_packages="$@"

    echo "Adding packages..."
    yum -y -q makecache >/dev/null 2>&1
    yum -y -q install zsh git sudo gnupg socat openssh-clients tar $additional_packages >/dev/null 2>&1
    yum -y clean all >/dev/null 2>&1

    change_root_shell

    add_oh_my_zsh

    initialize_root_shell

    configure_user_sudo $admin_group_name
}


configure_almalinux() {
    configure_centos_like adm,wheel 
}

configure_rocky() {
    configure_centos_like adm,wheel 
}

configure_centos() {
    configure_centos_like adm,wheel 
}


username=$(cat /etc/os-release | grep ^ID= | cut -d= -f 2)
if [ -z "$username" ]; then
    echo "Can't find distribution flavor"
    exit 1
fi
echo "We are on $username"

configure_$username

echo "Configuration done."
touch /etc/wsl-configured
