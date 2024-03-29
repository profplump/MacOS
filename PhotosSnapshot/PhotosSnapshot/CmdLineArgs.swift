//
//  CmdLineArgs.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-21.
//  Copyright © 2023 Zi3. All rights reserved.
//

import ArgumentParser
import Foundation

let default_mediaTypes = "APV"
let default_dateFormat = "yyyy-MM-dd_HH-mm-ss"

@main
struct CmdLineArgs: ParsableCommand {
    @Argument(help: "Destination parent folder. Snapshots are created in folders under this path")
    var parent: String

    @Option(name: .shortAndLong, help: "Append this existing snapshot (path relative to `<parent>`) instead of creating a new snapshot folder")
    var append: String?
    
    @Option(name: .long, help: "Use APFS clones to resources in this existing snapshot (path relative to `<parent>`) to create a complete snapshot without re-fetching unchanged resources. Fetches only resources that have changed since the timestamp of `<base>` or the provided `--incremental-date`")
    var clone: String?
    @Option(name: .long, help: "Use hardlinks to resources in this existing snapshot (path relative to `<parent>`) to create a complete snapshot without re-fetching unchanged resources. Fetches only resources that have changed since the timestamp of `<base>` or the provided `--incremental-date`")
    var hardlink: String?
    @Option(name: .long, help: "Use symlinks to resources in this existing snapshot (path relative to `<parent>`) to create a complete snapshot without re-fetching unchanged resources. Fetches only resources that have changed since the timestamp of `<base>` or the provided `--incremental-date`")
    var symlink: String?
    
    @Option(name: .long, help: "Verify the content of this existing snapshot (path relative to `<parent>`). Ignores assets newer than the snapshot timestamp (or `--compare-date`)")
    var verify: String?

    @Option(name: .shortAndLong, parsing: .remaining, help: "One or more UUIDs to fetch. This option does not support the media-types filter. This option must appear last -- any remaining arguments are treated as UUIDs")
    var uuid: [String] = []
    
    @Option(name: .shortAndLong, help: "Filter media types by included or excluding them in this string. Use A for audio, P for photos and V for video. Default: APV")
    var mediaTypes: String = default_mediaTypes
    
    @Option(name: .shortAndLong, help: "Limit fetch requests to at most this many results. Default: 0 <unlimited>")
    var fetchLimit: Int?
    
    @Option(name: .shortAndLong, help: "A DateFormatter template for use in naming snapshot folders. Default: yyyy-MM-dd_HH-mm-ss")
    var dateFormat: String = default_dateFormat
    
    @Option(name: .shortAndLong, help: "A date string, in the format specified in date-format, for use in incremental backups. This overrides folder-based date determinations")
    var compareDate: String? = nil

    @Flag(name: .shortAndLong, help: "Issue a warning when a resource file already exists. By default existing files are ignored and counted as successful fetches")
    var warnExists: Bool = false

    @Flag(name: .shortAndLong, help: "Disable network (iCloud) fetch requests -- only process local assets")
    var localOnly: Bool = false

    @Flag(name: .shortAndLong, help: "Do not include Hidden assets in fetch results")
    var noHidden: Bool = false
    
    @Flag(name: .long, help: "Do not fetch resource content, just create empty files")
    var dryRun: Bool = false
        
    @Flag(name: .shortAndLong, help: "Print additional runtime information")
    var verbose: Bool = false
    
    mutating func run() throws {
        // Override command-line args with ENV variables
        let env = ProcessInfo.processInfo.environment
        if (env.index(forKey: "LOCAL_ONLY") != nil) {
            localOnly = true
        }
        if (env.index(forKey: "WARN_EXISTS") != nil) {
            warnExists = true
        }
        if (env.index(forKey: "DRY_RUN") != nil) {
            dryRun = true
        }
        if let value = env["DATE_FORMAT"] {
             dateFormat = value
        }
        if let value = env["COMPARE_DATE"] {
            compareDate = value
        }
        if let value = env["FETCH_LIMIT"] {
             fetchLimit = Int(value)
        }
        if let value = env["MEDIA_TYPES"] {
             mediaTypes = value
        }
        
        // Basic cleanup and sanity checks
        mediaTypes = mediaTypes.uppercased()
        var isDir: ObjCBool = true
        if (!FileManager.default.fileExists(atPath: parent, isDirectory: &isDir)) {
            print("Invalid parent folder: \(parent)")
            return
        }

        // Try to ensure these options are sensible
        if (verify != nil && (clone != nil || symlink != nil || hardlink != nil)) {
            print("Incremental and verify operations are mutually exclusive")
            return
        }
        if (!uuid.isEmpty) {
            if (mediaTypes != default_mediaTypes) {
                print("UUID-based fetches ignores media-types")
                mediaTypes = default_mediaTypes
            }
        }

        // Start chatting
        if (verbose) {
            print("Verbose: Enabled")
        }
        
        // Run it
        PhotosSnapshot(options: self).main();
    }
}
