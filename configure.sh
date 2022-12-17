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

# Change the root shell to /bin/zsh
change_root_shell() {
    echo "Change root shell to zsh"
    # This method is portable (alpine would need apk shadow for chsh)
    sed -ie '/^root:/ s#:/bin/.*$#:/bin/zsh#' /etc/passwd
}


# Add Oh my ZSH and additional plugins to /usr/share
#
# Some distributions provide a oh-my-zsh package but its better to clone it
# for updates.
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


# Initializes the user home directory.
#
# @param $1 the user name to configure.
#
# Performs the following operations:
# - Install the Oh My ZSH .zshrc template.
# - Install the PowerLevel10k confiuguration to pimp the prompt 
#   (`p10k configure` to change)
# - Create the ~/.ssh directory (will contains the agent socket)
# - Initializes the gpg directory.
initialize_user_home() {
    local user=$1
    local homedir=$(getent passwd $user | cut -d: -f 6)

    if [ ! -z "$homedir" ]; then
        echo "Configuring $user home directory $homedir..."
        install -m 700 -o $user -g $user /usr/share/oh-my-zsh/templates/zshrc.zsh-template $homedir/.zshrc
        install -m 740 -o $user -g $user ./p10k.zsh $homedir/.p10k.zsh
        install --directory -o $user -g $user -m 0700 $homedir/.ssh
        su -l $user -c "gpg -k" >/dev/null 2>&1
    fi
}

# Add a non root sudo user
#
# @param $1 The user name
# @para $2 The additional groups to add to the user (wheel, adm, admin...)
add_sudo_user() {
    local user=$1
    local admin_group_name=$2
    if ! getent passwd $user >/dev/null; then
        echo "Configuring user $user..."
        useradd --comment "$user User" --create-home --user-group --uid 1000 --shell /bin/zsh --non-unique $user
        usermod --groups $admin_group_name $user
        echo 'Defaults env_keep += "SSH_AUTH_SOCK"' >/etc/sudoers.d/10_$user
        echo "$user ALL=(ALL) NOPASSWD: ALL" >>/etc/sudoers.d/10_$user
        chmod 0440 /etc/sudoers.d/10_$user
        initialize_user_home $user
    else
        echo "User $user already configured"
    fi
}

# Configure a debian like system (Ubuntu, Debian, ...)
# 
# @param $1 list of groups separated by commas of the groups to add to the sudo
#           user. The administrative groups may differ from distribution to 
#           distribution (staff, wheel, admin).
# @param $@ list of additionnal packages to add.
#
# Performs the following operations:
# - Add required packages (zsh and al.)
# - Change root shell to zsh
# - Add Oh my ZSH and plugins to the system
# - Configure the root home directory to use oh-my-zsh with the PowerLevel10K 
#   theme
# - Add a sudo user derived from the name of the distribution with the 
#   appropriate configuration and groups
configure_debian_like() {
    local admin_group_name=$1
    shift
    local additional_packages="$@"

    echo "Adding packages..."
    apt update -qq >/dev/null 2>&1
    apt-get install -qq -y zsh git sudo iproute2 gnupg socat openssh-client $additional_packages >/dev/null 2>&1
    apt-get clean

    change_root_shell

    add_oh_my_zsh

    initialize_user_home root

    add_sudo_user $username $admin_group_name
}

# Configure a Debian system
# @see configure_debian_like
configure_debian() {
    configure_debian_like staff curl
}

# Configure a Ubuntu system
# @see configure_debian_like
configure_ubuntu() {
    configure_debian_like admin
}


# Configure an Alpine system
# 
# Performs the following operations:
# - Add the edge repository
# - Add required packages (zsh and al.)
# - Change root shell to zsh
# - Add Oh my ZSH and plugins to the system
# - Configure the root home directory to use oh-my-zsh with the PowerLevel10K 
#   theme
# - Add a doas user derived from the name of the distribution with the 
#   appropriate configuration and groups
# - Configure OpenRC so it doesn't complain when started.
configure_alpine() {
    set -o pipefail

    echo "Adding packages..."
    grep -q edge /etc/apk/repositories || echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories
    apk update --quiet
    apk add --quiet --no-progress --no-cache zsh tzdata git libstdc++ doas iproute2 gnupg socat openssh openrc

    change_root_shell

    add_oh_my_zsh

    initialize_user_home root

    if ! getent passwd $username; then
        echo "Configuring user $username..."
        adduser -s /bin/zsh -g $username -D $username
        addgroup $username wheel
        echo "permit nopass keepenv :wheel" >> /etc/doas.d/doas.conf
        initialize_user_home $username
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


# Configure an Arch Linux system
# 
# Performs the following operations:
# - Generate the locale
# - Configure pacman
# - Add required packages (zsh and al.)
# - Change root shell to zsh
# - Add Oh my ZSH and plugins to the system
# - Configure the root home directory to use oh-my-zsh with the PowerLevel10K 
#   theme
# - Add a sudo user derived from the name of the distribution with the 
#   appropriate configuration and groups
# - Configure OpenRC so it doesn't complain when started.
configure_arch() {
    set -o pipefail

    FQDN="archbase"
    COUNTRY="fr"
    LANGUAGE="en_US.UTF-8"
    YAY_VERSION="11.1.2"

    if [ ! -f /etc/locale.conf ]; then
        echo "LANG=${LANGUAGE}" >/etc/locale.conf
        /usr/bin/locale-gen $LANGUAGE >/dev/null 2>&1
    fi

    echo "Initializing pacman..."

    if [ ! -f /etc/pacman.d/mirrorlist.orig ]; then
        cp /etc/pacman.d/mirrorlist /etc/pacman.d/mirrorlist.orig
    fi
    echo 'Server = https://mirror.cyberbits.eu/archlinux/$repo/os/$arch' > /etc/pacman.d/mirrorlist

    # Initialize pacman keyring before installing packages
    pacman-key --init >/dev/null 2>&1
    pacman-key --populate archlinux  >/dev/null 2>&1
    sed -i -e 's/^CheckSpace/#CheckSpace/' /etc/pacman.conf
    
    echo "Adding packages..."
    # Update keyring before system in order to provision new keys
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

    initialize_user_home root

    # This is for running rootless containers (see https://gist.github.com/lbrame/84d445fae17ad98cd6969b30b0f118e8)
    touch /etc/subuid
    touch /etc/subgid
    add_sudo_user $username adm,wheel
}


# Configure a RHEL like system (CentOS, Almalinux, ...)
# 
# @param $1 the name of the package manager (yum, dnf)
# @param $2 list of groups separated by commas of the groups to add to the sudo
#           user. The administrative groups may differ from distribution to 
#           distribution (staff, wheel, admin).
# @param $@ list of additionnal packages to add.
#
# Performs the following operations:
# - Add required packages (zsh and al.)
# - Change root shell to zsh
# - Add Oh my ZSH and plugins to the system
# - Configure the root home directory to use oh-my-zsh with the PowerLevel10K 
#   theme
# - Add a sudo user derived from the name of the distribution with the 
#   appropriate configuration and groups
configure_rhel_like() {
    local pkmgr=$1
    shift
    local admin_group_name=$1
    shift
    local additional_packages="$@"

    echo "Adding packages..."
    $pkmgr -y -q makecache >/dev/null 2>&1
    $pkmgr -y -q install zsh git sudo gnupg socat openssh-clients tar $additional_packages >/dev/null 2>&1
    $pkmgr -y clean all >/dev/null 2>&1

    change_root_shell

    add_oh_my_zsh

    initialize_user_home root

    add_sudo_user $username $admin_group_name
}

# Configure an Alma Linux System
# @ see configure_rhel_like
configure_almalinux() {
    configure_rhel_like yum adm,wheel 
}

# Configure a Rocky Linux System
# @ see configure_rhel_like
configure_rocky() {
    configure_rhel_like yum adm,wheel 
}

# Configure a CentOS Linux System
# @ see configure_rhel_like
configure_centos() {
    configure_rhel_like yum adm,wheel 
}


# Configure an OpenSuse Linux System
# @ see configure_rhel_like
configure_opensuse() {
    echo "max_parallel_downloads=10" >> /etc/dnf/dnf.conf
    echo "fastestmirror=True" >> /etc/dnf/dnf.conf

    configure_rhel_like dnf trusted curl gzip
}

username=$(cat /etc/os-release | grep ^ID= | cut -d= -f 2 | tr -d '"' | cut -d"-" -f 1)
if [ -z "$username" ]; then
    echo "Can't find distribution flavor"
    exit 1
fi
echo "We are on $username"

configure_$username

echo "Configuration done."
touch /etc/wsl-configured
