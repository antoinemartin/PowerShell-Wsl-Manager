FROM alpine:3.19

# Add the dependencies
RUN echo "http://dl-cdn.alpinelinux.org/alpine/edge/testing/" >> /etc/apk/repositories ;\
    apk update --quiet ;\
    apk add --quiet --no-progress --no-cache zsh tzdata git libstdc++ doas iproute2 gnupg socat openssh openrc

# Change root shell
RUN sed -ie '/^root:/ s#:/bin/.*$#:/bin/zsh#' /etc/passwd

# Add Oh-my-zsh
RUN git clone --quiet --depth 1 https://github.com/ohmyzsh/ohmyzsh.git /usr/share/oh-my-zsh && \
    sed -i -e 's#^export ZSH=.*#export ZSH=/usr/share/oh-my-zsh#g' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    git clone --quiet --depth=1 https://github.com/romkatv/powerlevel10k.git /usr/share/oh-my-zsh/custom/themes/powerlevel10k && \
    git clone --quiet --depth=1  https://github.com/zsh-users/zsh-autosuggestions "/usr/share/oh-my-zsh/custom/plugins/zsh-autosuggestions" && \
    git clone --quiet --depth 1 https://github.com/antoinemartin/wsl2-ssh-pageant-oh-my-zsh-plugin "/usr/share/oh-my-zsh/custom/plugins/wsl2-ssh-pageant" && \
    sed -ie '/^plugins=/ s#.*#plugins=(git zsh-autosuggestions wsl2-ssh-pageant)#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    sed -ie '/^ZSH_THEME=/ s#.*#ZSH_THEME="powerlevel10k/powerlevel10k"#' /usr/share/oh-my-zsh/templates/zshrc.zsh-template && \
    echo '[[ ! -f ~/.p10k.zsh ]] || source ~/.p10k.zsh' >> /usr/share/oh-my-zsh/templates/zshrc.zsh-template

# OpenRC stuff
RUN mkdir -p /lib/rc/init.d && \
    ln -s /lib/rc/init.d /run/openrc && \
    touch /lib/rc/init.d/softlevel

ADD rc.conf /etc/rc.conf

# Configure root user
USER root
RUN install -m 700 -o root -g root /usr/share/oh-my-zsh/templates/zshrc.zsh-template /root/.zshrc && \
    install --directory -o root -g root -m 0700 /root/.ssh && \
    gpg -k >/dev/null 2>&1

COPY --chown=root:root ./p10k.zsh /root/.p10k.zsh

# Add user alpine
RUN adduser -s /bin/zsh -g alpine -D alpine && \
    addgroup alpine wheel && \
    echo "permit nopass keepenv :wheel" >> /etc/doas.d/doas.conf

# Configure user alpine
USER alpine

RUN install -m 700 -o alpine -g alpine /usr/share/oh-my-zsh/templates/zshrc.zsh-template /home/alpine/.zshrc && \
    install --directory -o alpine -g alpine -m 0700 /home/alpine/.ssh && \
    gpg -k >/dev/null 2>&1

COPY --chown=alpine:alpine ./p10k.zsh /home/alpine/.p10k.zsh

# Run shell by default. Allows using the docker image
CMD /bin/zsh
