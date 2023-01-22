# PhotosSnapshot

PhotosSnapshot is a command-line tool for creating backups of Apple Photos assets. It can process both locally-stored files and iCloud data and is built on the PhotoKit SDK.

PhotosSnapshot creates a filesystem-based backup for Photos assets including audio, photos, videos, and live photos. The original, modified, and alternate (i.e. RAW) versions of all assets, if available, are copied to the destination folder. Assets are represented as folders and named according to the identifier used by PhotoKit[^1]. Resources are grouped into asset folders and named by type.

[^1]: Which matches the asset UUID from the Photos Library SQLite DB

I wrote this tool to allow me to backup my iCloud-stored photos without using all the local storage required for "Download Originals to this Mac".

I hope to extend this tool to support lightweight incremental snapshots, using APFS COW clones and/or hardlinks to provide a time-series of complete snapshots without unncessarily duplicating the underlying data, much like Time Machine.

This project is not based on but was inspired by [PhotosExporter](https://github.com/abentele/PhotosExporter) by Andreas Bentele. Their tool makes similar lightweight clones - probably better ones - but can only backup local assets. That workflow doesn't suit my needs but their project did convince me I could write a Swift PhotoKit app, which was very helpful.

## Usage

PhotosSnapshot will prompt for full access to your Photos the first time it is run. If you select a destination folder with special access restrictions (e.g. Desktop or Documents) it will also prompt to access that location.

### Create Snapshot

`PhotosSnapshot <parent>`

`PhotosSnapshot /Volumes/BackupDisk/Snapshots`

This will download all assets of all enabled types into a new snapshot at `<parent>/<datetime>`

--

### Append Snapshot

`PhotosSnapshot -b <base> <parent>`

`PhotosSnapshot -b 2023-01-11_12-13-14 /Volumes/BackupDisk/Snapshots`

The value of value of `base` should match the subfolder of an existing snapshot in the same parent folder

This will reprocess the existing snapshot by adding new assets and retrying any missing resources. It will not modify (nor verify) any existing files.

--

### Fetch Specific Assets

`PhotosSnapshot <parent> <UUID_1> <UUID_2>... <UUID_N>`

`PhotosSnapshot /Volumes/BackupDisk/Snapshots 5DF52E20-7411-4748-98C9-211422F97563 431C6A1C-1BC3-4450-B6C8-76CEA3972542`

Where the value of the second and any subsequent arguements are UUIDs as expected by PhotoKit. When used in this mode MEDIA_TYPES are ignored and assets of any supported type will be fetched.

## Arguments, Options, and Flags

parent
: Destination parent folder. Snapshots are created in folders at `<parent>/<date>`

--base
: An existing snapshot, relative to `<parent>`. Required for append or incremental operations

--append
: Append the existing snapshot at `<base>`

--incremental
: Create a new incremental backup using `<base>` as a prior snapshot

--uuid
: One or more UUIDs to fetch. This option does not support the media-types filter or incremental operation

--media-types
: Restrict fetch requests to assets with the specified media type. Use A for audio, P for images, and V for videos. Does not apply to UUID-based searches `-m APV`

--fetch-limit
: Limit fetch requests to the specified number of assets `-f 10`

--date-format
: A DateFormatter format string for use in naming snapshot folders. Default: yyyy-MM-dd_hh-mm-ss `-d "yyyy-MM-dd"`

--warn-exists
: Issue a warning when a resource file already exists. By default existing files are ignored and counted as successful fetches `-w`

--local-only
: Disable network (iCloud) fetch requests -- only process local assets `-l`

--no-hidden
: Do not include Hidden assets in fetch results `-n`

--verbose
: Enable additional runtime output `-v`


## Environmental Variables

Environmental variables will override command-line parameters of the same name

- MEDIA_TYPES
- FETCH_LIMIT
- WARN_EXISTS
- DATE_FORMAT
- NO_HIDDEN
- LOCAL_ONLY
