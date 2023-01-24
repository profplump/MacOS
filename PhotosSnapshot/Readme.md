# PhotosSnapshot

PhotosSnapshot is a command-line tool for creating backups of Apple's Photos Library assets. It can process both locally-stored and iCloud assets and is built on the PhotoKit SDK. It is intended to produce stand-alone filesystem-based backups of all assets in the Photos Library, and can produce Time Machine-like thin-copy snapshots for space-efficient but complete incremental snapshots.

PhotosSnapshot creates a filesystem-based backup for Photos assets including audio, photos, videos, and live photos. The original, modified, and alternate (i.e. RAW) versions of assets, if available, are copied to the destination folder. Assets are represented as folders and named according to the identifier used by PhotoKit[^1]. Resources are grouped into asset folders and named by type.

[^1]: Which matches the asset UUID from the Photos Library SQLite DB, if you want to query against it for other metadata

I wrote this tool to allow me to backup iCloud-stored photos without using the local storage required for "Download Originals to this Mac".

This project is not based on but was inspired by [PhotosExporter](https://github.com/abentele/PhotosExporter) by Andreas Bentele. Their tool makes similar lightweight snapshots but can only backup local assets. That workflow doesn't suit my needs but their project did convince me I could write a Swift PhotoKit app, which was very helpful.

## Usage

### Typical Workflow

1. Manually create a single snapshot: `PhotosSnapshot /Volumes/BackupDisk/Snapshots`
1. Create a periodic (e.g. daily) incremental snapshot with: `PhotosSnapshot --clone -b LATEST /Volumes/BackupDisk/Snapshots`
1. Run a periodic (e.g. monthly) verification, to ensure that the complete snapshot is intact: `PhotosSnapshot --verify -b LATEST /Volumes/BackupDisk/Snapshots`
1. Manually remove any resources that `verify` complains about and replace them by appending assets with: `PhotosSnapshot --append -b LASTEST /Volumes/BackupDisk/Snapshots`, optionally using `--uuid` to specify the specific assets you want to re-fetch

### Create Snapshot

`PhotosSnapshot <parent>`

`PhotosSnapshot /Volumes/BackupDisk/Snapshots`

This will download all assets of all enabled types into a new snapshot at `<parent>/<datetime>`

--

### Incremental Snapshot

`PhotosSnapshot --clone -b <base> <parent>`

`PhotosSnapshot --clone -b RECENT /Volumes/BackupDisk/Snapshots`

This will create a new snapshot based on the most recent existing snapshot, by cloning[^2] resources from any valid assets from the `<base>` snapshot, and then by fetching assets that are missing from `<base>` or that have been updated since the `<base>` snapshot timestamp (or `--compare-date`).

[^2]: Clones are available when fetching to an APFS volume. `--symlink` and `--hardlink` produce similar behaviors on other filesystems. Symlinks will also work across volumes, though they are less robust as an archive format

--

### Incremental Sparse Snapshot

`PhotosSnapshot --incremental -b <base> <parent>`

`PhotosSnapshot --incremental -b 2023-01-11_12-13-14 /Volumes/BackupDisk/Snapshots`

This will create a new, sparse snapshot by fetching assets that are missing from `<base>` or that have been updated since the `<base>` snapshot timestamp (or `--compare-date`). Valid assets that exist in `<base>` are not fetched in a sparse snapshot.

--

### Append Snapshot

`PhotosSnapshot --append -b <base> <parent>`

`PhotosSnapshot --append -b 2023-01-11_12-13-14 /Volumes/BackupDisk/Snapshots`

This will reprocess an existing snapshot by adding new assets and retrying any missing resources. It will not modify (nor verify) any existing resources.

--

### Verify Snapshot

`PhotosSnapshot --verify -b <base> <parent>`

`PhotosSnapshot --verify -b 2023-01-11_12-13-14 /Volumes/BackupDisk/Snapshots`

This will verify every resource in `<base>` by downloading a new copy and doing a byte comparision of the existing file. Disk usage is minimal as resources are fetch, verified, and immediately deleted. Errors will be reported if assets do not exist, are not readable, or do not exactly match the current version. Assets with creation or modification times after the snapshot timestamp (or `--compare-date`) are ignored.

--

### Fetch Specific Assets

`PhotosSnapshot <parent> --uuid <UUID_1> <UUID_2>... <UUID_N>`

`PhotosSnapshot /Volumes/BackupDisk/Snapshots --uuid 5DF52E20-7411-4748-98C9-211422F97563 431C6A1C-1BC3-4450-B6C8-76CEA3972542`

Any arguments after the flag `--uuid` are treated as UUIDs and fed to PhotoKit. When used in this mode `--media-types` are ignored and assets of any supported type will be fetched. Maybe be combined with any operation to fetch, append, incremental, or verify specific assets in an existing archive.


## Arguments, Options, and Flags

parent
: Destination parent folder. Snapshots are created in folders under this path

`/Volumes/BackupDisk/Snapshots`

--base
: An existing snapshot path, relative to `<parent>`. Required for append, incremental, and verify operations. Use the keyword `RECENT` to select the most recent snapshot in `<parent>`

`-b 2023-01-11_12-13-14`

`-b RECENT`

--append
: Append the existing snapshot at `<base>`

--incremental
: Create a new incremental backup using `<base>` as a prior snapshot. Fetches only resources that have changed since the timestamp of `<base>` or the provided `--compare-date`

--clone
: Use APFS clones to resources in `<base>` to create a complete snapshot without re-fetching unchanged resources. Implies `--incremental`

--hardlink
: Use hardlinks to resources in `<base>` to create a complete snapshot without re-fetching unchanged resources. Implies `--incremental`

--symlink
: Use symlinks to resources in `<base>` to create a complete snapshot without re-fetching unchanged resources. Implies `--incremental`

--uuid
: One or more UUIDs to fetch. This option does not support the media-types filter. This option must appear last as any futher arguments are treated as UUIDs

`-u 5DF52E20-7411-4748-98C9-211422F97563 431C6A1C-1BC3-4450-B6C8-76CEA3972542`

--media-types
: Restrict fetch requests to assets with the specified media type. Use A for audio, P for images, and V for videos. Does not apply to UUID-based searches

`-m APV`

--fetch-limit
: Limit fetch requests to the specified number of assets

`-f 10`

--date-format
: A DateFormatter template for use in naming snapshot folders. Default: yyyy-MM-dd_HH-mm-ss

`-d yyyy-MM-dd`

--compare-date
: A date string, in the format specified in date-format, for use in incremental operations. This overrides folder-based date determinations

`-c 2020-01-01_00-00-00`

--warn-exists
: Issue a warning when a resource file already exists. By default existing files are ignored and counted as successful fetches

--local-only
: Disable network (iCloud) fetch requests -- only process local assets

--no-hidden
: Do not include Hidden assets in fetch results

--dry-run
: Do not copy resource content, just create empty files

--verify
: Verify the content of an existing snapshot at `<base>`. Ignores assets newer than the snapshot timestamp (or `--compare-date`)

--verbose
: Enable additional runtime output


## Environmental Variables

Environmental variables will override command-line parameters of the same name

- MEDIA_TYPES
- FETCH_LIMIT
- DATE_FORMAT
- COMPARE_DATE
- WARN_EXISTS
- LOCAL_ONLY
- NO_HIDDEN
- DRY_RUN
