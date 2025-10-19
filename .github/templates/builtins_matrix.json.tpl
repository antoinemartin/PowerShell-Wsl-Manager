{{ $alpine_version := or (env.Getenv "ALPINE_DEFAULT_VERSION") "3.22.1" }}
{{ $archlinux_version := or (env.Getenv "ARCH_DEFAULT_VERSION") "2025.08.01" }}
{
  "include": [
    {
        "flavor": "arch",
        "version": "{{ $archlinux_version }}",
        "url": "https://archive.archlinux.org/iso/{{ $archlinux_version }}/archlinux-bootstrap-{{ $archlinux_version }}-x86_64.tar.zst"
    },
    {
        "flavor": "alpine",
        "version": "{{ $alpine_version }}",
        "url": "https://dl-cdn.alpinelinux.org/alpine/v{{ $alpine_version | regexp.Replace "\\.\\d+$" "" }}/releases/x86_64/alpine-minirootfs-{{ $alpine_version }}-x86_64.tar.gz"
     },
    {
        "flavor": "ubuntu",
        "version": "latest",
        "url": "https://cdimages.ubuntu.com/ubuntu-wsl/daily-live/current/resolute-wsl-amd64.wsl"
    },
    {
        "flavor": "debian",
        "version": "latest",
        "url": "https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/stable/rootfs.tar.xz"
    },
    {
        "flavor": "opensuse",
        "version": "latest",
        "url": "https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz"
    }
  ]
}
