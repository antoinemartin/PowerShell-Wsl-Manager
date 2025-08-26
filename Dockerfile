# syntax=docker/dockerfile:1.3-labs
# cSpell: disable
FROM alpine:edge as builder

ARG USERNAME=alpine
ARG GROUPNAME=alpine

# Add the dependencies
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories ;\
    apk update --quiet ;\
    apk add --quiet --no-progress --no-cache zsh tzdata git libstdc++ doas iproute2 gnupg socat openssh openrc

# Change root shell
RUN sed -ie '/^root:/ s#:/bin/.*$#:/bin/zsh#' /etc/passwd

# Add Oh-my-zsh and plugins. Create user skeleton that includes it
RUN git clone --quiet --depth 1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh && \
    sed -i -e 's#^export ZSH=.*#export ZSH=/usr/share/oh-my-zsh#g' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    git clone --quiet --depth=1 https://github.com/romkatv/powerlevel10k.git /usr/share/oh-my-zsh/custom/themes/powerlevel10k && \
    git clone --quiet --depth=1  https://github.com/zsh-users/zsh-autosuggestions "/usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions" && \
    git clone --quiet --depth 1 https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin "/usr/share/oh-my-zsh/custom/plugins/wsl2-ssh-pageant" && \
    sed -ie '/^plugins=/ s#.*#plugins=(git zsh-autosuggestions wsl2-ssh-pageant)#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    sed -ie '/^ZSH_THEME=/ s#.*#ZSH_THEME="powerlevel10k/powerlevel10k"#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    mkdir -p /etc/skel && \
    install -m 700 -o root -g root /usr/share/oh-my-zsh/templates/zshrc.zsh-template /etc/skel/.zshrc  && \
    wget -O /etc/skel/.p10k.zsh https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/main/p10k.zsh && \
    install --directory -o root -g root -m 0700 /etc/skel/.ssh && \
    touch /etc/subuid && touch /etc/subgid

# Allow OpenRC to run as non init
RUN mkdir -p /lib/rc/init.d && \
    ln -s /lib/rc/init.d /run/openrc && \
    touch /lib/rc/init.d/softlevel

COPY <<EOF /etc/rc.conf
rc_sys="prefix"
rc_controller_cgroups="NO"
rc_depend_strict="NO"
rc_need="!net !dev !udev-mount !sysfs !checkfs !fsck !netmount !logger !clock !modules"
EOF

# Configure the root user for zsh/oh-my-zsh/powerlevel10k
USER root
RUN install -m 700 -o root -g root /usr/share/oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc && \
    install --directory -o root -g root -m 0700 /root/.ssh && \
    wget -O /root/.p10k.zsh https://raw.githubusercontent.com/antoinemartin/PowerShell-Wsl-Manager/refs/heads/main/p10k.zsh && \
    (gpg -k && gpgconf --kill keyboxd || /bin/true) >/dev/null 2>&1

# Add user alpine
RUN adduser -s /bin/zsh -g ${USERNAME} -D ${GROUPNAME} && \
    addgroup ${USERNAME} wheel && \
    echo "permit nopass keepenv :wheel" >> /etc/doas.d/doas.conf # && \
    echo "Host *" > /home/${USERNAME}/.ssh/config && echo " StrictHostKeyChecking no" >> /home/${USERNAME}/.ssh/config && \
    chown -R ${USERNAME}:${GROUPNAME} /home/${USERNAME}/.ssh && \
    su -l ${USERNAME} -c "gpg -k && gpgconf --kill keyboxd || /bin/true" >/dev/null 2>&1

# Set WSL default user
COPY <<EOF2 /etc/wsl.conf
[user]
default = "${USERNAME}"
EOF2

# Create the final image as a single layer image by copying builder contents
FROM scratch
ARG USERNAME=alpine

COPY --from=builder / /

# FIXME: The following command adds one layer to the image
# WORKDIR /home/${USERNAME}
USER ${USERNAME}

# Run shell by default. Allows using the docker image as devcontainer
CMD /bin/zsh
