# PhotosSnapshot

PhotosSnapshot is a command-line tool for creating backups of Apple Photos assets. It can process both locally-stored files and iCloud data and is built on the PhotoKit SDK. It is intended to produce stand-alone filesystem-based backups of all assets in the Photos Library, and can produce Time Machine-like thin-copy snapshots for efficient but complete incremental snapshots.

PhotosSnapshot creates a filesystem-based backup for Photos assets including audio, photos, videos, and live photos. The original, modified, and alternate (i.e. RAW) versions of all assets, if available, are copied to the destination folder. Assets are represented as folders and named according to the identifier used by PhotoKit[^1]. Resources are grouped into asset folders and named by type.

[^1]: Which matches the asset UUID from the Photos Library SQLite DB, if you want to query against it for other metadata

I wrote this tool to allow me to backup my iCloud-stored photos without using all the local storage required for "Download Originals to this Mac".

This project is not based on but was inspired by [PhotosExporter](https://github.com/abentele/PhotosExporter) by Andreas Bentele. Their tool makes similar lightweight snapshots but can only backup local assets. That workflow doesn't suit my needs but their project did convince me I could write a Swift PhotoKit app, which was very helpful.

## Usage

PhotosSnapshot will prompt for full access to your Photos the first time it is run. If you select a destination folder with special access restrictions (e.g. Desktop or Documents) it will also prompt to access that location.

### Create Snapshot

`PhotosSnapshot <parent>`

`PhotosSnapshot /Volumes/BackupDisk/Snapshots`

This will download all assets of all enabled types into a new snapshot at `<parent>/<datetime>`

--

### Incremental Snapshot

`PhotosSnapshot --clone -b <base> <parent>`

`PhotosSnapshot --clone -b 2023-01-11_12-13-14 /Volumes/BackupDisk/Snapshots`

The value of value of `base` should match the subfolder of an existing snapshot in the same parent folder

This will create a new, thin snapshot by fetching assets that are missing or have been updated since the `<base>` snapshot timestamp (or the `--compare-date` if provided) and cloning[^2] any assets already exist in the `<base>` snapshot

[^2]: Clones are available when fetching to an APFS volume. `--symlink` and `--hardlink` produce similar behaviors on other filesystems. Volume support for the thin-copy mode is checked at runtime

--

### Incremental Partial Snapshot

`PhotosSnapshot --incremental -b <base> <parent>`

`PhotosSnapshot --incremental -b 2023-01-11_12-13-14 /Volumes/BackupDisk/Snapshots`

The value of value of `base` should match the subfolder of an existing snapshot in the same parent folder

This will create a new, sparse snapshot by fetching assets that are missing or have been updated since the `<base>` snapshot timestamp (or the `--compare-date` if provided). Other assets are not cloned and would need to be manually integrated with the `<base>` snapshot to produce a complete snapshot

--

### Append Snapshot

`PhotosSnapshot --append -b <base> <parent>`

`PhotosSnapshot --append -b 2023-01-11_12-13-14 /Volumes/BackupDisk/Snapshots`

The value of value of `base` should match the subfolder of an existing snapshot in the same parent folder

This will reprocess the existing snapshot by adding new assets and retrying any missing resources. It will not modify (nor verify) any existing files.

--

### Fetch Specific Assets

`PhotosSnapshot <parent> --uuid <UUID_1> <UUID_2>... <UUID_N>`

`PhotosSnapshot /Volumes/BackupDisk/Snapshots --uuid 5DF52E20-7411-4748-98C9-211422F97563 431C6A1C-1BC3-4450-B6C8-76CEA3972542`

Where the value of the second and any subsequent arguements are UUIDs as expected by PhotoKit. When used in this mode MEDIA_TYPES are ignored and assets of any supported type will be fetched.

## Arguments, Options, and Flags

parent
: Destination parent folder. Snapshots are created in folders under this path

`/Volumes/BackupDisk/Snapshots`

--base
: An existing snapshot, relative to `<parent>`. Required for append or incremental operations

`-b 2023-01-11_12-13-14`

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
: One or more UUIDs to fetch. This option does not support the media-types filter or incremental operation

`-u 5DF52E20-7411-4748-98C9-211422F97563 431C6A1C-1BC3-4450-B6C8-76CEA3972542`

--media-types
: Restrict fetch requests to assets with the specified media type. Use A for audio, P for images, and V for videos. Does not apply to UUID-based searches

`-m APV`

--fetch-limit
: Limit fetch requests to the specified number of assets

`-f 10`

--date-format
: A DateFormatter format string for use in naming snapshot folders. Default: yyyy-MM-dd_hh-mm-ss

`-d yyyy-MM-dd`

--compare-date
: A date string, in the format specified in date-format, for use in incremental operations. This overrides folder-based date determinations

`-k 2020-01-01_00-00-00`

--warn-exists
: Issue a warning when a resource file already exists. By default existing files are ignored and counted as successful fetches

--local-only
: Disable network (iCloud) fetch requests -- only process local assets

--no-hidden
: Do not include Hidden assets in fetch results

--dry-run
: Do not copy resource content, just create empty files

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
