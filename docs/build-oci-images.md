# Building Custom Root FS as OCI Images

This document explains how to use the GitHub Actions workflow that builds custom
WSL root filesystems and publishes them as OCI-compatible images to GitHub
Container Registry (ghcr.io).

## Overview

The `build-rootfs-oci.yaml` workflow allows you to build custom WSL root
filesystems for different Linux distributions and push them as container images
to ghcr.io. This makes it easy to distribute and version your custom WSL images.

## Triggering the Workflow

The workflow can be triggered in two ways:

### 1. Manual Trigger (Workflow Dispatch)

You can trigger it manually using GitHub's workflow dispatch feature:

### Via GitHub Web Interface

1. Go to the "Actions" tab in your GitHub repository
2. Select "Build and Push Custom Root FS as OCI Image" from the workflow list
3. Click "Run workflow"
4. Fill in the required parameters:
   - **Flavor**: Choose from `ubuntu`, `arch`, `alpine`, `debian`, or `opensuse`
   - **Version**: Specify a version tag for your image (e.g., `1.0.0`, `latest`,
     `2025.08.01`)
5. Click "Run workflow"

### Via GitHub CLI

```bash
gh workflow run build-rootfs-oci.yaml \
  --field flavor=arch \
  --field version=2025.08.01
```

### Via REST API

```bash
curl -X POST \
  -H "Authorization: token YOUR_TOKEN" \
  -H "Accept: application/vnd.github.v3+json" \
  https://api.github.com/repos/OWNER/REPO/actions/workflows/build-rootfs-oci.yaml/dispatches \
  -d '{"ref":"main","inputs":{"flavor":"arch","version":"2025.08.01"}}'
```

### 2. Automatic Trigger (Pull Request)

The workflow also runs automatically on pull requests targeting the `main`
branch for testing purposes. When triggered this way, it uses default values
defined as environment variables:

- **Flavor**: `arch` (defined as `FLAVOR` environment variable)
- **Version**: `2025.08.01` (defined as `VERSION` environment variable)

The workflow includes a `set-variables` job that:

- Uses workflow dispatch inputs when manually triggered
- Falls back to environment variable defaults when triggered by pull request
- Makes the selected values available to all subsequent jobs via job outputs

Each job that needs the flavor and version values creates local environment
variables from the job outputs in its first step, making the workflow code
cleaner and easier to read.

This allows you to test the workflow changes before merging to main.

## Supported Flavors

- **ubuntu**: Ubuntu 24.04 Noble WSL rootfs
- **arch**: Arch Linux (built from bootstrap image)
- **alpine**: Alpine Linux 3.19 minirootfs
- **debian**: Debian Bookworm
- **opensuse**: OpenSUSE Tumbleweed

## Output

The workflow produces OCI-compatible container images pushed to:

```
ghcr.io/OWNER/REPO/miniwsl:FLAVOR-VERSION
ghcr.io/OWNER/REPO/miniwsl:FLAVOR-latest  # only for main branch
```

For example:

- `ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl:ubuntu-1.0.0`
- `ghcr.io/antoinemartin/powershell-wsl-manager/miniwsl:arch-latest`

## Using the Images

Once built, these OCI images can be:

1. **Pulled and converted back to WSL rootfs**:

   ```bash
   docker pull ghcr.io/OWNER/REPO/miniwsl:ubuntu-1.0.0
   docker create --name temp ghcr.io/OWNER/REPO/miniwsl:ubuntu-1.0.0
   docker export temp | gzip > ubuntu-custom.rootfs.tar.gz
   docker rm temp
   ```

2. **Used directly in container environments** that support OCI images

3. **Referenced in other workflows** as base images for further customization

## Customization

The workflow includes the same customization logic as the release workflow:

- Installs `p10k.zsh` configuration
- Runs `configure.sh` script for distribution-specific setup
- Creates a minimal, optimized WSL environment

## Permissions

The workflow requires the following permissions:

- `contents: read` - to checkout the repository
- `packages: write` - to push images to ghcr.io

Make sure your repository has the necessary permissions configured for GitHub
Packages.
