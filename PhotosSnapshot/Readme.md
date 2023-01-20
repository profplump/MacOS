# PhotosSnapshot

PhotosSnapshot is a command-line tool for creating partial and full backups of Apple Photos assets. It can process both locally-stored files and iCloud data and is built on the PhotoKit SDK.

PhotosSnapshot creates a filesystem-based backup for Photos assets including photos, videos, and live photos. The original, modified, and alternate (i.e. RAW) versions of all assets, if available, are  copied to the destination folder. Assets are represented as folders and named according to the identifier used by PhotoKit[^1]. Resources are grouped by asset folder and named by type, with file extension that matches their data type.

[^1]: Which matches the asset UUID from the Photos Library SQLite DB

I wrote this tool to allow me to backup my iCloud-stored photos without using all the local storage required for "Download Originals to this Mac".

I hope to extend this tool to support lightweight incremental snapshots, using APFS COW clones or hardlinks to provide a time series of complete snapshots without unncessary duplicating the underlying data, much like Time Machine.

This project is not based on but was inspired by [PhotosExporter](https://github.com/abentele/PhotosExporter) by Andreas Bentele. Their tool makes similar lightweight clones - probably better ones - but can only work the local assets. That workflow doesn't suit my needs but their project did convince me I could write a Swift PhotoKit app, which was very helpful.

## Usage

PhotosSnapshot will prompt for full access to your Photos the first time it is run. If you select a destination folder with special access restrictions (e.g. Desktop or Documents) it will also prompt to access that location.

### Create Snapshot

`PhotosSnapshot destFolder`

PhotosSnapshot will download all assets of all types into a snapshot at `destFolder/<currentDateTime>`

--

### Update Snapshot

`DATE_STRING="2023-01-18_18-01-23" PhotosSnapshot destFolder`

Where the value of `DATE_STRING` matches the subfolder used in the existing snapshot

This will reprocess the existing snapshot by adding new assets and retrying any missing resources

Use `WARN_EXISTS` to log existing resource files (which are never modified)


--

### Fetch Specific Assets

`PhotosSnapshot destFolder UUID1 UUID2 UUID3`

Where the value of the second and any subsequent arguements are UUIDs as expected by PhotoKit. When used in this mode MEDIA_TYPES are ignored and assets of any supported type will be fetched.


## Environmental Variables

PhotosSnapshot supports several environmental variables to control operation at runtime

MEDIA_TYPES
: Restrict fetch requests to assets with the specified media type. Use A for audio, P for images, and V for videos. Does not apply to UUID-based searches `MEDIA_TYPES="APV"`

FETCH_LIMIT
: Limit fetch requests to the specified number of assets `FETCH_LIMIT=10`

WARN_EXISTS
: If set, issue a warning when a resource file already exists. This warning is disabled by default to allow retries if a snapshot does not complete cleanly `WARN_EXISTS=1`

NO_SUBFOLDER
: If set, store assets in destFolder directly, without a date-based subfolder `NO_SUBFOLDER=1`

DATE_FORMAT
: If set, override the default date format of "yyyy-MM-dd_hh-mm-ss" with the provided string `DATE_FORMAT="yyyy-MM-dd"`

DATE_STRING
: If set, override the date string with the provided string `DATE_STRING="2023-01-18_18-01-23"`

NO_HIDDEN
: If set, do not include Hidden assets in fetch requests `NO_HIDDEN=1`

NO_NETWORK
: If set, disable access to remote (iCloud) resources. Resources with local file backing will still be copied. If you only wish to backup local file this option can be much faster. `NO_NETWORK=1`
