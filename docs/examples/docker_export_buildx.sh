#!/usr/bin/env zsh

image=$1
tag=$2

# If docker is not running, ensure it is installed and started
if ! [ -f /var/run/docker.pid ]; then
    apk add docker docker-cli-buildx
    rc-update add docker default
    openrc default
fi

# Create a temporary directory as context of the image
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT

# We retrieve the windows local app data
local=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -NoLogo -C '$env:LOCALAPPDATA' | tr -d '\r')

# We create the docker file.
echo "FROM $image:$tag" > $dir/Dockerfile

# We build the image asking for a tar output
docker buildx b --output type=tar $dir | gzip >$(wslpath "$local")/Wsl/RootFS/$image.rootfs.tar.gz
