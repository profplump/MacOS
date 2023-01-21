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

`PhotosSnapshot destFolder`

PhotosSnapshot will download all assets of all enabled types into a snapshot at `destFolder/<currentDateTime>`

--

### Update Snapshot

`DATE_STRING="2023-01-18_18-01-23" PhotosSnapshot destFolder`

The value of `DATE_STRING` should match the subfolder used in an existing snapshot

This will reprocess the existing snapshot by adding new assets and retrying any missing resources. It will not modify (nor verify) any existing files.

--

### Fetch Specific Assets

`PhotosSnapshot destFolder UUID1 UUID2 UUID3`

Where the value of the second and any subsequent arguements are UUIDs as expected by PhotoKit. When used in this mode MEDIA_TYPES are ignored and assets of any supported type will be fetched.


## Environmental Variables

MEDIA_TYPES
: Restrict fetch requests to assets with the specified media type. Use A for audio, P for images, and V for videos. Does not apply to UUID-based searches `MEDIA_TYPES="APV"`

FETCH_LIMIT
: Limit fetch requests to the specified number of assets `FETCH_LIMIT=10`

WARN_EXISTS
: Issue a warning when a resource file already exists. `WARN_EXISTS=1`

NO_SUBFOLDER
: Store assets in `destFolder` directly, without a Date subfolder `NO_SUBFOLDER=1`

DATE_FORMAT
: Override the default date format of "yyyy-MM-dd_hh-mm-ss" with the provided format string `DATE_FORMAT="yyyy-MM-dd"`

DATE_STRING
: Override the subfolder Date string with the provided string `DATE_STRING="2023-01-18_18-01-23"`

NO_HIDDEN
: Do not include Hidden assets in fetch requests `NO_HIDDEN=1`

NO_NETWORK
: Disable access to remote (iCloud) resources. Resources with local resource files will still be copied. If you only wish to backup locally-available assets this can be much faster `NO_NETWORK=1`
