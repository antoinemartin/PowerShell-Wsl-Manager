# 2.0 Roadmap

Version 1.5 introduced the ability to pull root filesystems for distributions
from Docker registries. The goal is to enhance this functionality further and
align it more closely with Docker workflows.

## Manage Root Filesystems Like Docker Images

Root filesystems will include metadata about the underlying operating system and
will be identified by name and tag.

The `Get-WslRootFileSystem` cmdlet will return output similar to:

```console
    Name               Tag     Type  OS           Release      Configured              State Name
    ----               ---     ----  --           -------      ----------              ----- ----
    yawsldocker-alpine latest  Uri   alpine       3.22.1       True                   Synced alpine.3.22.1.rootfs.tar.gz
```

Configured distributions will be referenced by their distribution name (e.g.,
`arch`, `alpine`), while base distributions will use a `-base` suffix (e.g.,
`arch-base`, `alpine-base`).

- [x] Implemented URL parsing and removal of Configured parameter.

## URL-Like Distribution Names

Distributions will be identified using URL-like structures for easier management
and retrieval. For example:

`docker://ghcr.io/antoinemartin/yawsldocker/yawsldocker-alpine#latest`

This structure indicates the distribution's source and version.

When a specified name is not a URL, it will default to:

- `builtin://<name>#latest`, or
- `docker://ghcr.io/antoinemartin/powershell-wsl-manager/<name>#latest`

Incus root filesystems will require a prefix change from `incus:` to `incus://`.

The `New-WslRootFileSystem` cmdlet will accept parameters for all root
filesystem properties, particularly for digest computation. These may be
specified as URL parameters, allowing complete compact representation of root
filesystem information.

## Remove Local Root Filesystem Information

Fetch distribution information dynamically instead of storing it locally. This
enables more current and up-to-date information about available distributions
and their versions.

~~The GitHub Actions workflow that builds images will also build base filesystem
images. Consider using base Docker images for each distribution instead of
fetching root filesystems directly.~~

## Simplified Installation

~~During installation, make pulling new root filesystem versions an explicit
user choice with the `-Sync` parameter instead of automatic updates. Similarly,
make configuration explicit with the `-Configure` parameter rather than
requiring users to opt out. Add the `Invoke-Configure` cmdlet to enable
post-installation configuration.~~

## Post-Installation Modifications

- ~~Add an `Update-Wsl` cmdlet for easy WSL distribution updates~~ It is unclear
  for now on how to properly implement this.
- ~~Add a `Set-Wsl` for setting options on distributions.~~ **Note** Only
  implemented for DefaultUid changes.
- ~~Add `Rename-Wsl` cmdlet to allow users to easily change the name of their
  WSL distributions.~~

## Implementation Tasks (Claude's proposal)

The following tasks outline the step-by-step implementation plan for version
2.0, organized to ensure each task results in a releasable package while
minimizing the need for subsequent refactoring.

### Phase 1: Infrastructure and Core Refactoring

#### Task 1.1: Implement URL-Like Distribution Names Parser

- **Scope**: Create a robust URL parser for distribution identifiers
- **Implementation**:
  - Add `ConvertFrom-WslDistributionUrl` function to parse URL-like distribution
    names
  - Support schemes: `builtin://`, `docker://`, `incus://`, `file://`
  - Implement default URL resolution logic (builtin and docker defaults)
  - Add comprehensive parameter validation and error handling
- **Output**: Core URL parsing functionality that supports all planned
  distribution sources
- **Release Impact**: Backward compatible - existing functionality unchanged,
  new URL parsing available

#### Task 1.2: Enhance Root Filesystem Metadata Model

- **Scope**: Extend the root filesystem object model to include comprehensive
  metadata
- **Implementation**:
  - Add `WslRootFileSystemMetadata` class with OS detection from Docker labels
  - Implement metadata extraction from Docker image labels
    (`org.opencontainers.image.*`)
  - Add support for detecting OS name, version, and architecture from container
    metadata
  - Update `Get-WslRootFileSystem` output format to match roadmap specification
- **Output**: Rich metadata support for all distribution types
- **Release Impact**: Enhanced information display, backward compatible output
  format

#### Task 1.3: Refactor Distribution Configuration System

- **Scope**: Modernize how distributions are defined and managed
- **Implementation**:
  - Replace static `Distributions.psd1` with dynamic distribution discovery
  - Implement base vs configured distribution naming (`-base` suffix logic)
  - Create `Get-WslDistributionDefinition` cmdlet for dynamic distribution
    lookup
  - Update all existing cmdlets to use new distribution resolution system
- **Output**: Dynamic, extensible distribution management system
- **Release Impact**: More accurate and up-to-date distribution information

### Phase 2: Enhanced Installation and Management

#### Task 2.1: Implement Explicit Installation Parameters

- **Scope**: Add explicit control over installation steps
- **Implementation**:
  - Add `-Sync` parameter to `Install-Wsl` for explicit root filesystem updates
  - Add `-Configure` parameter to `Install-Wsl` for explicit configuration
    control
  - Create `Invoke-Configure` cmdlet for post-installation configuration
  - Update installation workflow to be explicit rather than automatic
- **Output**: User-controlled installation process with clear options
- **Release Impact**: More predictable installation behavior, enhanced user
  control

#### Task 2.2: Add Distribution Management Cmdlets

- **Scope**: Implement missing distribution management functionality
- **Implementation**:
  - Create `Update-Wsl` cmdlet with `-User` parameter for updating default users
  - Create `Rename-Wsl` cmdlet for changing distribution names
  - Add comprehensive parameter validation and error handling
  - Implement proper WSL integration for all operations
- **Output**: Complete set of distribution management tools
- **Release Impact**: Full distribution lifecycle management capabilities

### Phase 3: Advanced Features and Optimization

#### Task 3.1: Implement Dynamic Distribution Discovery

- **Scope**: Remove dependency on local distribution information
- **Implementation**:
  - Remove static distribution data from `Distributions.psd1`
  - Implement real-time fetching of distribution information from registries
  - Add caching mechanism for performance optimization
  - Create fallback mechanisms for offline scenarios
- **Output**: Always current distribution information without local maintenance
- **Release Impact**: Self-updating distribution catalog, reduced maintenance
  overhead

#### Task 3.2: Enhanced Docker Registry Integration

- **Scope**: Improve Docker registry functionality and error handling
- **Implementation**:
  - Add support for multiple registry types (Docker Hub, GHCR, Azure CR)
  - Implement registry authentication improvements
  - Add retry logic and better error messages for registry operations
  - Optimize image layer downloading with resume capability
- **Output**: Robust, production-ready registry integration
- **Release Impact**: More reliable Docker image operations, better user
  experience

#### Task 3.3: URL Parameter Support for Root Filesystems

- **Scope**: Enable complete root filesystem specification via URLs
- **Implementation**:
  - Add URL parameter parsing for digest computation settings
  - Support authentication parameters in URLs
  - Implement tag and digest-based image referencing
  - Add validation for complete URL-based specifications
- **Output**: Compact, complete root filesystem specification format
- **Release Impact**: Advanced users can specify complete configurations via
  URLs

### Phase 4: Module Modernization and Release Preparation

#### Task 4.1: Update Module Manifest and Documentation

- **Scope**: Prepare module for 2.0 release
- **Implementation**:
  - Update module version to 2.0.0 in `Wsl-Manager.psd1`
  - Add new cmdlets to module exports
  - Update PowerShell Gallery metadata and tags
  - Refresh all help documentation and examples
- **Output**: Complete 2.0 module ready for distribution
- **Release Impact**: Official 2.0 release with full feature set

#### Task 4.2: Comprehensive Testing and Validation

- **Scope**: Ensure reliability and backward compatibility
- **Implementation**:
  - Expand unit test coverage for all new functionality
  - Add integration tests for Docker registry operations
  - Implement backward compatibility validation tests
  - Add performance benchmarks for new features
- **Output**: Thoroughly tested, reliable 2.0 release
- **Release Impact**: High-quality, stable module suitable for production use

#### Task 4.3: Migration Guide and Breaking Changes

- **Scope**: Document any breaking changes and provide migration assistance
- **Implementation**:
  - Document all parameter and behavior changes
  - Create migration scripts for existing users
  - Add deprecation warnings for removed functionality
  - Provide upgrade documentation and examples
- **Output**: Smooth upgrade path for existing users
- **Release Impact**: Minimal disruption for existing users upgrading to 2.0

### Release Strategy

Each task is designed to result in a functional, releasable package:

- **After Task 1.x**: Enhanced core functionality with new URL parsing and
  metadata
- **After Task 2.x**: Complete installation and management feature set
- **After Task 3.x**: Advanced registry integration and dynamic discovery
- **After Task 4.x**: Production-ready 2.0 release

This phased approach ensures that users benefit from improvements incrementally
while maintaining stability and backward compatibility throughout the
development process.
