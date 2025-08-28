# Building Custom Root FS as OCI Images

This page explains how to use the GitHub Actions workflow that builds custom WSL
images and publishes them as OCI-compatible images to GitHub Container Registry
(ghcr.io).

## Overview

The `build-rootfs-oci.yaml` workflow allows you to build custom WSL root
filesystems for different Linux distributions and push them as container images
to `ghcr.io`. This makes it easy to distribute and version your custom WSL
images.

## Triggering the Workflow

The workflow can be triggered in three ways:

### 1. Manual Trigger (Workflow Dispatch)

You can trigger it manually using GitHub's workflow dispatch feature to build a
single flavor:

#### Via GitHub Web Interface

1. Go to the "Actions" tab in your GitHub repository
2. Select "Build and Push Custom Root FS as OCI Image" from the workflow list
3. Click "Run workflow"
4. Fill in the required parameter:
   - **Flavor**: Choose from `ubuntu`, `arch`, `alpine`, `debian`, or `opensuse`
5. Click "Run workflow"

#### Via GitHub CLI

```bash
gh workflow run build-rootfs-oci.yaml \
  --field flavor=arch
```

#### Via REST API

```bash
curl -X POST \
  -H "Authorization: token YOUR_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/OWNER/REPO/actions/workflows/build-rootfs-oci.yaml/dispatches \
  -d '{"ref":"main","inputs":{"flavor":"arch"}}'
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

## Supported Flavors

The workflow supports the following Linux distributions with their respective
sources:

- **ubuntu**: Ubuntu WSL Image from
  `https://cdimages.ubuntu.com/ubuntu-wsl/daily-live/current/questing-wsl-amd64.wsl`
- **arch**: Arch Linux bootstrap image from
  `https://archive.archlinux.org/iso/VERSION/archlinux-bootstrap-VERSION-x86_64.tar.zst`
- **alpine**: Alpine Linux minirootfs from
  `https://dl-cdn.alpinelinux.org/alpine/vX.Y/releases/x86_64/alpine-minirootfs-X.Y.Z-x86_64.tar.gz`
- **debian**: Debian rootfs from
  `https://doi-janky.infosiftr.net/job/tianon/job/debuerreotype/job/amd64/lastSuccessfulBuild/artifact/stable/rootfs.tar.xz`
- **opensuse**: OpenSUSE Tumbleweed from
  `https://download.opensuse.org/tumbleweed/appliances/opensuse-tumbleweed-dnf-image.x86_64-lxc-dnf.tar.xz`

## Build Process Overview

1. **Variable Setup**: Uses gomplate to generate build matrix from template,
   determining flavors and versions based on trigger type
2. **Rootfs Download**: Fetches appropriate base rootfs for each flavor from
   upstream sources
3. **Arch Special Handling**: For Arch Linux, repackages bootstrap image to
   remove directory prefix
4. **OS Information Extraction**: Dynamically extracts version and flavor
   information from the rootfs
5. **Base Image Creation**: Creates unmodified base OCI image using Dockerfile
   template
6. **Environment Setup**: Prepares chroot environment with mounted filesystems
   for customization
7. **Configuration**: Applies customizations using provided scripts in chroot
   environment
8. **Configured Image Creation**: Builds and pushes customized OCI image using
   Dockerfile template
9. **Metadata Generation**: Creates JSON metadata files for both base and
   configured images
10. **Artifact Upload**: Uploads metadata for collection (deploy/images branch
    only)
11. **Metadata Publishing**: Collects and publishes metadata to rootfs branch
    (deploy/images branch only)

## Architecture

The workflow consists of three main jobs:

### 1. set-variables

This job determines the build matrix based on the trigger type:

- Uses gomplate to generate the build matrix from the `builtins_matrix.json.tpl`
  template
- For workflow dispatch: filters to build only the selected flavor
- For automatic triggers (deploy branch/scheduled): builds all supported flavors
- Outputs the matrix configuration for use by subsequent jobs

### 2. build-and-push-rootfs

This is the main job that runs for each flavor in the matrix and:

- Sets environment variables from the matrix (FLAVOR, VERSION, UPSTREAM_URL)
- Downloads the base filesystem from the upstream URL
- For Arch Linux: repackages the bootstrap image to remove the `root.x86_64`
  prefix
- Extracts OS information from the rootfs to dynamically determine version and
  flavor
- Creates both base and configured OCI images:
  - **Base image** (FLAVOR-base): Unmodified rootfs with root user
  - **Configured image** (FLAVOR): Customized rootfs with regular user
- Uses gomplate templates to generate Dockerfiles for both image types
- Builds custom rootfs with chroot environment configuration
- Generates JSON metadata for both image variants
- Uploads artifacts for metadata collection

### 3. collect-rootfs-metadata & publish-rootfs-metadata

These jobs run only on the `deploy/images` branch and:

- **collect-rootfs-metadata**: Downloads all JSON metadata artifacts and
  combines them
- **publish-rootfs-metadata**: Commits the collected metadata to the `rootfs`
  branch as `builtins.rootfs.json`

## Output

The workflow produces OCI-compatible container images pushed to GitHub Container
Registry. For each flavor, two images are created:

### Base Images (Unmodified):

```
ghcr.io/OWNER/REPO/FLAVOR-base:VERSION
ghcr.io/OWNER/REPO/FLAVOR-base:latest
```

### Configured Images (Customized):

```
ghcr.io/OWNER/REPO/FLAVOR:VERSION
ghcr.io/OWNER/REPO/FLAVOR:latest
```

For example:

- `ghcr.io/antoinemartin/powershell-wsl-manager/arch-base:2025.08.01`
- `ghcr.io/antoinemartin/powershell-wsl-manager/arch:2025.08.01`
- `ghcr.io/antoinemartin/powershell-wsl-manager/alpine-base:3.22.1`
- `ghcr.io/antoinemartin/powershell-wsl-manager/alpine:3.22.1`
- `ghcr.io/antoinemartin/powershell-wsl-manager/ubuntu-base:latest`
- `ghcr.io/antoinemartin/powershell-wsl-manager/ubuntu:latest`

## Using the Images

Once built, these OCI images can be:

1. **Used directly with Wsl-Manager** by referencing the Docker URI:

   ```powershell
   # Example of using configured Docker image as image source
   New-WslInstance myubuntu -From docker://ghcr.io/OWNER/REPO/ubuntu:latest

   # Example of using base Docker image as image source
   New-WslInstance myubuntu -From docker://ghcr.io/OWNER/REPO/ubuntu-base:latest
   ```

2. **Used as builtin images**:

   ```powershell
   # Uses the configured image (equivalent to FLAVOR:latest)
   New-WslInstance myubuntu -From ubuntu

   # Uses the base image (equivalent to FLAVOR-base:latest)
   New-WslInstance myubuntu -From ubuntu-base
   ```

3. **Pulled and converted back to WSL rootfs**:

   ```bash
   docker pull ghcr.io/OWNER/REPO/ubuntu:latest
   docker create --name temp ghcr.io/OWNER/REPO/ubuntu:latest
   docker export temp | gzip > ubuntu-custom.rootfs.tar.gz
   docker rm temp
   ```

4. **Used directly in container environments** that support OCI images

5. **Referenced in other workflows** as base images for further customization

## Customization

The workflow includes comprehensive customization logic that creates two types
of images:

### Base Images

- Contains the unmodified rootfs from upstream sources
- Uses root user (UID 0)
- No custom configuration applied
- Tagged as `FLAVOR-base`

### Configured Images

- **Downloads base rootfs** from official distribution sources
- **Mounts necessary filesystems** (`/dev`, `/proc`, `/sys`) for chroot
  environment
- **Installs configuration files**:
  - `p10k.zsh` - Powerlevel10k Zsh theme configuration
  - `configure.sh` - Distribution-specific setup script
- **Runs configuration** in a chroot environment as root
- **Cleans up** temporary files and unmounts filesystems
- **Creates optimized WSL rootfs** with all customizations applied
- **Uses regular user** with the flavor name as username (UID 1000)
- Tagged as `FLAVOR`

The customization process ensures that each configured flavor gets:

- A minimal, optimized WSL environment
- Consistent shell configuration across all distributions
- Distribution-specific optimizations and package installations
- Proper user setup for WSL usage

## Permissions

The workflow requires the following permissions:

- `contents: read` - to checkout the repository
- `packages: write` - to push images to ghcr.io
- `contents: write` - to commit metadata to the rootfs branch (deploy/images
  branch only)

Make sure your repository has the necessary permissions configured for GitHub
Packages.

## Dynamic Version Detection

The workflow includes intelligent version detection that:

- Extracts OS information from the downloaded rootfs using `os-release` files
- Uses extracted `VERSION_ID` or `IMAGE_VERSION` to override default versions
  when available
- Uses extracted `ID` to override the flavor name when available
- Falls back to matrix-defined versions when OS information is not available
- Outputs all extracted variables for debugging and transparency

This ensures that the built images use the actual version information from the
rootfs rather than potentially outdated defaults.

## Template System

The workflow uses [gomplate](https://github.com/hairyhenderson/gomplate)
templates to generate configuration files dynamically:

### Matrix Template (`builtins_matrix.json.tpl`)

- Defines supported flavors with their versions and upstream URLs
- Uses environment variables for default versions (`ARCH_DEFAULT_VERSION`,
  `ALPINE_DEFAULT_VERSION`)
- Generates the build matrix consumed by the workflow

### Dockerfile Template (`Builtin.dockerfile.tpl`)

- Creates Dockerfiles for both base and configured images
- Uses variables like `WSL_UID`, `WSL_USERNAME`, `WSL_CONFIGURED`, `WSL_TYPE`
- Allows consistent Dockerfile generation across all flavors

### Metadata Template (`rootfs.json.tpl`)

- Generates JSON metadata describing each built image
- Includes information about user configuration, image type, and Docker
  references
- Used for builtin image resolution in Wsl-Manager

This template-based approach ensures consistency and maintainability across all
supported distributions.
