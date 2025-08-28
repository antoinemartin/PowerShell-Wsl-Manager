FROM scratch
ADD {{ .Env.WSL_ROOTFS_TAR_GZ }} /
LABEL org.opencontainers.image.source="https://github.com/{{ .Env.GITHUB_REPOSITORY }}"
LABEL org.opencontainers.image.description="WSL {{ .Env.WSL_TYPE }} {{ .Env.FLAVOR }} Linux Root FS"
LABEL org.opencontainers.image.flavor="{{ .Env.FLAVOR }}"
LABEL org.opencontainers.image.version="{{ .Env.VERSION }}"
LABEL com.kaweezle.wsl.rootfs.uid="{{ .Env.WSL_UID }}"
LABEL com.kaweezle.wsl.rootfs.username="{{ .Env.WSL_USERNAME }}"
LABEL com.kaweezle.wsl.rootfs.configured="{{ .Env.WSL_CONFIGURED }}"
USER {{ .Env.WSL_USERNAME }}
