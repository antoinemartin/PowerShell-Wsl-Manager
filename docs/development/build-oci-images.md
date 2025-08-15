# Building Custom Root FS as OCI Images

This page explains how to use the GitHub Actions workflow that builds custom WSL
root filesystems and publishes them as OCI-compatible images to GitHub Container
Registry (ghcr.io).

## Overview

The `build-rootfs-oci.yaml` workflow allows you to build custom WSL root
filesystems for different Linux distributions and push them as container images
to ghcr.io. This makes it easy to distribute and version your custom WSL images.

## Triggering the Workflow

The workflow can be triggered in three ways:

### 1. Manual Trigger (Workflow Dispatch)

You can trigger it manually using GitHub's workflow dispatch feature to build a
single flavor:

#### Via GitHub Web Interface

1. Go to the "Actions" tab in your GitHub repository
2. Select "Build and Push Custom Root FS as OCI Image" from the workflow list
3. Click "Run workflow"
4. Fill in the required parameters:
   - **Flavor**: Choose from `ubuntu`, `arch`, `alpine`, `debian`, or `opensuse`
   - **Version**: Specify a version tag for your image:
     - For **Arch**: Format `YYYY.MM.DD` (e.g., `2025.08.01`)
     - For **Alpine**: Format `X.Y.Z` (e.g., `3.22.1`)
     - For **Ubuntu, Debian, OpenSUSE**: Use `latest`
5. Click "Run workflow"

#### Via GitHub CLI

```bash
gh workflow run build-rootfs-oci.yaml \
  --field flavor=arch \
  --field version=2025.08.01
```

#### Via REST API

```bash
curl -X POST \
  -H "Authorization: token YOUR_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/OWNER/REPO/actions/workflows/build-rootfs-oci.yaml/dispatches \
  -d '{"ref":"main","inputs":{"flavor":"arch","version":"2025.08.01"}}'
```

### 2. Automatic Trigger (Deploy Branch)

The workflow runs automatically when you push to the `deploy/images` branch.
This triggers a build of all supported flavors with their default versions.

### 3. Scheduled Trigger

The workflow runs automatically every Sunday at 2:00 AM UTC to build fresh
images with the latest updates for all flavors.

## Version Requirements

The workflow enforces specific version formats for different flavors:

- **Arch Linux**: Must use format `YYYY.MM.DD` (e.g., `2025.08.01`)
- **Alpine**: Must use format `X.Y.Z` (e.g., `3.22.1`)
- **Ubuntu, Debian, OpenSUSE**: Must use `latest`

## Default Versions

When triggered automatically (push or schedule), the workflow uses these default
versions:

- **Arch**: `2025.08.01`
- **Alpine**: `3.22.1`
- **Ubuntu**: `latest`
- **Debian**: `latest`
- **OpenSUSE**: `latest`

The workflow includes a `set-variables` job that:

- Uses workflow dispatch inputs when manually triggered
- Falls back to default values when triggered automatically
- Makes the selected values available to all subsequent jobs via job outputs

Each job that needs the flavor and version values creates local environment
variables from the job outputs in its first step, making the workflow code
cleaner and easier to read.

This allows you to test the workflow changes before merging to main.

## Supported Flavors

The workflow supports the following Linux distributions with their respective
sources:

- **ubuntu**: Ubuntu WSL rootfs from
  `https://cdimages.ubuntu.com/ubuntu-wsl/daily-live/current/questing-wsl-amd64.wsl`
- **arch**: Arch Linux bootstrap image from
  `https://archive.archlinux.org/iso/VERSION/archlinux-bootstrap-VERSION-x86_64.tar.zst`
- **alpine**: Alpine Linux minirootfs from
  `https://dl-cdn.alpinelinux.org/alpine/vX.Y/releases/x86_64/alpine-minirootfs-X.Y.Z-x86_64.tar.gz`
- **debian**: Debian rootfs from
  `https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/stable/rootfs.tar.xz`
- **opensuse**: OpenSUSE Tumbleweed from
  `https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz`

## Architecture

The workflow consists of two main jobs:

### 1. build-archlinux-base

This job only runs for Arch Linux builds and:

- Downloads the Arch Linux bootstrap image
- Extracts and repackages it to remove the `root.x86_64` prefix
- Creates a base Arch Linux OCI image tagged as `arch-base`
- Uploads the processed rootfs as an artifact for the next job

### 2. build-and-push-rootfs

This job runs for all flavors and:

- Downloads the appropriate base rootfs for each flavor
- For Arch Linux, uses the artifact from the previous job
- Applies custom configuration using `configure.sh` and `p10k.zsh`
- Creates the final OCI image tagged as `miniwsl-FLAVOR`

## Output

The workflow produces OCI-compatible container images pushed to GitHub Container
Registry:

### For Arch Linux builds:

```
ghcr.io/OWNER/REPO/arch-base:VERSION
ghcr.io/OWNER/REPO/arch-base:latest
ghcr.io/OWNER/REPO/miniwsl-arch:VERSION
ghcr.io/OWNER/REPO/miniwsl-arch:latest
```

### For all other flavors:

```
ghcr.io/OWNER/REPO/miniwsl-FLAVOR:VERSION
ghcr.io/OWNER/REPO/miniwsl-FLAVOR:latest
```

For example:

- `ghcr.io/antoinemartin/powershell-wsl-manager/arch-base:2025.08.01`
- `ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-arch:2025.08.01`
- `ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-alpine:3.22.1`
- `ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl-ubuntu:latest`

## Using the Images

Once built, these OCI images can be:

1. **Used directly with Wsl-Manager** by referencing the Docker URI:

   ```powershell
   # Example of using Docker image as rootfs source
   Install-Wsl myubuntu -Distribution docker://ghcr.io/OWNER/REPO/miniwsl-ubuntu:latest
   ```

1. **Used as builtin images**:

   ```bash
   Install-Wsl myubuntu -Distribution Ubuntu -Configured
   ```

This will translate into the docker URL shown above.

1. **Pulled and converted back to WSL rootfs**:

   ```bash
   docker pull ghcr.io/OWNER/REPO/miniwsl-ubuntu:latest
   docker create --name temp ghcr.io/OWNER/REPO/miniwsl-ubuntu:latest
   docker export temp | gzip > ubuntu-custom.rootfs.tar.gz
   docker rm temp
   ```

1. **Used directly in container environments** that support OCI images

1. **Referenced in other workflows** as base images for further customization

## Customization

The workflow includes comprehensive customization logic:

- **Downloads base rootfs** from official distribution sources
- **Mounts necessary filesystems** (`/dev`, `/proc`, `/sys`) for chroot
  environment
- **Installs configuration files**:
  - `p10k.zsh` - Powerlevel10k Zsh theme configuration
  - `configure.sh` - Distribution-specific setup script
- **Runs configuration** in a chroot environment as root
- **Cleans up** temporary files and unmounts filesystems
- **Creates optimized WSL rootfs** with all customizations applied

The customization process ensures that each flavor gets:

- A minimal, optimized WSL environment
- Consistent shell configuration across all distributions
- Distribution-specific optimizations and package installations

## Build Process

1. **Variable Setup**: Determines build matrix based on trigger type
2. **Base Image Creation** (Arch only): Creates clean Arch Linux base
3. **Rootfs Download**: Fetches appropriate base rootfs for each flavor
4. **Environment Setup**: Prepares chroot environment with mounted filesystems
5. **Configuration**: Applies customizations using provided scripts
6. **Image Creation**: Builds and pushes OCI-compatible images to registry
7. **Cleanup**: Removes temporary files and artifacts

## Permissions

The workflow requires the following permissions:

- `contents: read` - to checkout the repository
- `packages: write` - to push images to ghcr.io

Make sure your repository has the necessary permissions configured for GitHub
Packages.
