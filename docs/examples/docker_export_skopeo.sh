#!/usr/bin/env zsh

# Retrieve image and tag from parameters
image=$1
tag=$2

# Create a temporary directory as destination of the image
dir=$(mktemp -d)
trap 'rm -rf "$dir"' EXIT
cd $dir

# Add the needed dependencies
apk add skopeo umoci libarchive-tools

# Retrieve the image
skopeo copy docker://$image:$tag oci:$image:$tag

# Unpack the image in the image subfolder
umoci unpack --image $image:$tag image

# Create the root filesystem
bsdtar -cpf $image.rootfs.tar.xz -C image/rootfs $(ls image/rootfs/)

# Move the filesystem where Wsl-Manager can find it
local=$(/mnt/c/Windows/System32/WindowsPowerShell/v1.0/powershell.exe -NoProfile -NoLogo -C '$env:LOCALAPPDATA' | tr -d '\r')
mv $image.rootfs.tar.xz $(wslpath "$local")/Wsl/RootFS/$image.rootfs.tar.gz
# keep this last line comment
