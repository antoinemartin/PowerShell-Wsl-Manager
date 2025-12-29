# SQLite database

This page describes the image catalog database used by the Wsl-Manager modules.
It is a small SQLite file that tracks available image sources (remote and
builtin) and the local images downloaded on disk.

## Location and lifetime

- The database file lives at `$env:LOCALAPPDATA/Wsl/RootFS/images.db` (or
  `$HOME/.local/share/Wsl/RootFS/images.db` on Linux, for testing purposes only)
  and is created on first use.
- The class `WslImageDatabase` wraps a `System.Data.SQLite.SQLiteConnection`
  through `SQLiteHelper` and provides typed methods to manipulate the tables.
- The helper function `Get-WslImageDatabase` opens a singleton instance of
  `WslImageDatabase`, runs pending migrations, and starts a 3-minute timer that
  closes the connection when idle. `Close-WslImageDatabase` ends the session
  early when needed.

## Schema overview

The initial structure is defined in [`Wsl-Image/db.sqlite`][db.sqlite].
Migrations in [`Wsl-Image/Wsl-Image.Database.ps1`][Wsl-Image.Database.ps1] add
columns and indexes over time.

```mermaid

erDiagram
    direction LR
    LocalImage }o--o|  ImageSource : "source"
    ImageSource o|--o{ ImageSourceCache : "cached in"
```

### Table: ImageSource

Tracks every known image source.

| Column          | Type / values | Notes                                                                                 |
| --------------- | ------------- | ------------------------------------------------------------------------------------- |
| Id              | TEXT, unique  | Random GUID when inserted.                                                            |
| CreationDate    | TEXT          | Default `CURRENT_TIMESTAMP`.                                                          |
| UpdateDate      | TEXT          | Updated automatically; set via `UpdateTimestampColumn`.                               |
| Name            | TEXT          | Human-friendly name.                                                                  |
| Tags            | TEXT          | Comma-separated tags. Part of the primary key since schema v7 (replaces Release).     |
| Url             | TEXT          | Source URL (HTTP, Docker, file, etc.).                                                |
| Type            | TEXT          | Image type enum string (e.g., `Builtin`, `Incus`, `Docker`, `Uri`, `Local`).          |
| Configured      | TEXT          | `'TRUE'` if the image is pre-configured; otherwise `'FALSE'`.                         |
| Username        | TEXT          | Default username for configured images.                                               |
| Uid             | INTEGER       | Default user UID for configured images.                                               |
| Distribution    | TEXT          | OS distribution identifier.                                                           |
| Release         | TEXT          | Release label kept for display and matching.                                          |
| LocalFilename   | TEXT          | Suggested filename for downloaded tarballs.                                           |
| DigestSource    | TEXT          | Hash origin (`docker`, `sums` or `single`).                                           |
| DigestAlgorithm | TEXT          | Hash algorithm (default `SHA256`).                                                    |
| DigestUrl       | TEXT          | URL to the digest file when provided.                                                 |
| Digest          | TEXT          | Hash value of the image.                                                              |
| GroupTag        | TEXT          | Batch tag used when refreshing builtins; older rows with a different tag are removed. |
| Size            | INTEGER       | Optional image size (bytes).                                                          |

Primary key: `(Type, Distribution, Tags, Configured)`; `Id` is also unique.

### Table: LocalImage

Represents images present (or expected) on disk. Most columns are copied from
the corresponding `ImageSource` row when created. This allows tracking local
state even if the source is later removed or updated.

| Column          | Type / values | Notes                                              |
| --------------- | ------------- | -------------------------------------------------- |
| Id              | TEXT, PK      | Random GUID per local entry.                       |
| ImageSourceId   | TEXT          | FK to ImageSource, nullable on delete.             |
| CreationDate    | TEXT          | Default `CURRENT_TIMESTAMP`.                       |
| UpdateDate      | TEXT          | Updated automatically on writes.                   |
| Name            | TEXT          | Derived from metadata or filename.                 |
| Tags            | TEXT          | Comma-separated tags for matching.                 |
| Url             | TEXT          | Mirrors source URL when applicable.                |
| State           | TEXT          | `Synced`, `NotDownloaded`, or `Outdated`.          |
| Type            | TEXT          | Same enum as `ImageSource` Type.                   |
| Configured      | TEXT          | `'TRUE'` when pre-configured; otherwise `'FALSE'`. |
| Username        | TEXT          | Default username for configured images.            |
| Uid             | INTEGER       | Default user UID for configured images.            |
| Distribution    | TEXT          | OS distribution identifier.                        |
| Release         | TEXT          | OS release label.                                  |
| LocalFilename   | TEXT          | Stored filename (often normalized to the hash).    |
| DigestSource    | TEXT          | Hash origin (`docker`, `sums` or `single`).        |
| DigestAlgorithm | TEXT          | Hash algorithm (default `SHA256`).                 |
| DigestUrl       | TEXT          | URL to the digest file when provided.              |
| Digest          | TEXT          | Hash value of the local image.                     |
| Size            | INTEGER       | Optional image size (bytes).                       |

There is a unique index on `(ImageSourceId, Name)` to prevent duplicates for the
same source.

### Table: ImageSourceCache

Stores the last-seen cache headers for builtin/remote catalogs (etag and
timestamp) to avoid redundant downloads.

| Column     | Type     | Notes                                                |
| ---------- | -------- | ---------------------------------------------------- |
| Type       | TEXT, PK | Matches `WslImageType`. Either `Builtin` or `Incus`. |
| Url        | TEXT     | Source URL used to fetch the catalog.                |
| LastUpdate | INTEGER  | Unix timestamp from the cache file.                  |
| Etag       | TEXT     | ETag used to detect changes.                         |

## Versioning and migrations

`WslImageDatabase` tracks the current schema version in `PRAGMA user_version`.
When opened, it runs `UpdateIfNeeded` to apply any missing migrations in order.
Each migration is a SQL snippet that modifies the schema or copies data as
needed. The current version is `7` as of this writing. The following is a
summary of the migrations:

1. Create base tables from `db.sqlite`.
2. Import cached builtin and Incus images into ImageSource.
3. Add `GroupTag` to ImageSource (used to tag refresh batches) and populate from
   cache etags.
4. Import existing local tarballs/JSON metadata into LocalImage
   (`TransferLocalImages`).
5. Add `Size` to ImageSource and LocalImage.
6. Add unique index on LocalImage `(ImageSourceId, Name)`.
7. Change ImageSource primary key to use `Tags` instead of `Release` (with data
   copy/rename).

Each step runs only once per database and bumps `user_version`.

## How the module uses the database

### Opening and caching

- There is a static singleton instance stored in `[WslImageDatabase]::Instance`.
- `Get-WslImageDatabase` opens the SQLite file, sets
  `UpdateTimestampColumn = 'UpdateDate'`, and schedules automatic close after
  inactivity (3 minutes).
- Callers are expected to reuse the singleton instead of opening new
  connections.

### Inserting and updating image sources and local images

For insertion and updates, the module uses `INSERT` statements with
[UPSERT clauses](https://www.sqlite.org/lang_UPSERT.html) to ensure atomicity
and avoid duplicates.

For image sources, the unique primary key on
`(Type, Distribution, Tags, Configured)` ensures that only one row exists per
combination. For Incus images, the Tags field contains the Release value. In
consequence, we will have only one `Incus/Ubuntu/22.04/FALSE` row for
`Ubuntu 22.04` whatsoever. For builtins, `Tags` contains `latest`, ensuring that
only one builtin per distribution exists.

For local images, the unique index on `(ImageSourceId, Name)` ensures that only
one local entry exists per name.

### Importing builtin catalogs

- The cmdlet `Update-WslBuiltinImageCache` downloads Builtin or Incus catalog
  from the github `rootfs` branch. It updates `ImageSourceCache`, and inserts
  rows into `ImageSource` with generated GUIDs through `SaveImageBuiltins`.
- `SaveImageBuiltins` writes new builtin rows with a `GroupTag` corresponding to
  the HTTP Response `ETag` Header, then deletes older rows for the same type and
  a different `GroupTag`. This ensures that only the latest builtins are kept.
- `SaveImageBuiltins` also marks matching `LocalImage` rows as `Outdated` when
  digests change.

### Managing individual image sources

- `SaveImageSource` upserts a single source (including digest and size data) and
  marks related local entries `Outdated` if the digest changes. This is used
  when refreshing local images or adding custom URIs.
- `GetImageSources` and `GetImageBuiltins` return typed `PSCustomObjects` for
  consumers.

### Importing local images

!!! warning "Migration from version prior to 3"

    Prior to version 3, local images were not tracked in a database. The images
    metadata was stored in `*.json` files alongside the tarballs. The migration step 4
    (`TransferLocalImages`) imports these files into the database and removes them
    afterward.
    This feature is primarily intended to migrate existing local images when
    upgrading the database schema. For regular use, prefer `Add-WslLocalImage` to
    register new local tarballs.

- `Move-LocalWslImage` scans the image base directory for `*.rootfs.tar.gz` and
  matching `*.json` metadata. Missing JSON files are synthesized via
  `New-WslImage-MissingMetadata` using file names and tarball contents.
- Each JSON entry is matched against existing ImageSource rows by
  type/distribution/release, URL, or digest. When none is found, a new
  ImageSource is created with a `GroupTag` matching the LocalImage ID.
- Local files are renamed to `<digest>.rootfs.tar.gz` (or
  `<algorithm>_<digest>.rootfs.tar.gz`) to ensure deterministic filenames,
  unless `-DoNotChangeFiles` is passed.
- The resulting LocalImage row is inserted with `State = 'Synced'` when the file
  exists or `NotDownloaded` otherwise. JSON metadata files are removed after
  import unless file changes are suppressed.

### Creating and updating local entries programmatically

- `[WslImageDatabase]::CreateLocalImageFromImageSource` clones a source row into
  LocalImage with `State = 'NotDownloaded'` and respects the unique index to
  avoid duplicates.
- `[WslImageDatabase]::SaveLocalImage` upserts LocalImage rows from cmdlet
  output, normalizing hash data and size when provided.
- `[WslImageDatabase]::RemoveLocalImage` and
  `[WslImageDatabase]::RemoveImageSource` delete rows safely; the foreign key
  uses `ON DELETE SET NULL` to keep local entries if their source is removed.

### Cache handling

- `[WslImageDatabase]::GetImageSourceCache` and
  `[WslImageDatabase]::UpdateImageSourceCache` read/write the cache table so
  callers can perform conditional requests (e.g., `ETag` comparison) when
  refreshing catalogs.

## Practical tips

- Always call `Get-WslImageDatabase` to obtain the shared connection and ensure
  migrations run.
- When introducing schema changes, add a migration block in `UpdateIfNeeded`,
  bump `CurrentVersion`, and add the SQL snippet alongside the others (similar
  to `AddImageSourceGroupTagSql`).
- Keep `Tags` populated; they are part of the primary key and are filled with
  `Release` when absent during migrations.
- Use the provided helpers (`SaveImageBuiltins`, `SaveImageSource`,
  `SaveLocalImage`) rather than issuing raw SQL so digests, states, and
  timestamps stay consistent.

[db.sqlite]:
  https://github.com/antoinemartin/PowerShell-Wsl-Manager/blob/dc89a6a/Wsl-Image/db.sqlite
[Wsl-Image.Database.ps1]:
  https://github.com/antoinemartin/PowerShell-Wsl-Manager/blob/bd06ce1/Wsl-Image/Wsl-Image.Database.ps1#L715
