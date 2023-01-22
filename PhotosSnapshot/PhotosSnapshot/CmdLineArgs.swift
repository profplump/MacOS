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
let default_dateFormat = "yyyy-MM-dd_hh-mm-ss"

@main
struct CmdLineArgs: ParsableCommand {
    @Argument(help: "Destination parent folder. Snapshots are created in folders at <parent>/<date_time>")
    var parent: String
    
    @Option(name: .shortAndLong, help: "An existing snapshot path, relative to <parent>. Required for append or incremental operations")
    var base: String?
    
    @Flag(name: .shortAndLong, help: "Append the existing snapshot at <base>")
    var append: Bool = false
    
    @Flag(name: .shortAndLong, help: "Create a new incremental backup using <base> as a prior snapshot")
    var incremental: Bool = false
    
    @Option(name: .shortAndLong, parsing: .remaining, help: "One or more UUIDs to fetch. This option does not support the media-types filter or incremental operation")
    var uuid: [String] = []
    
    @Option(name: .shortAndLong, help: "Filter media types by included or excluding them in this string. Use A for audio, P for photos and V for video. Default: APV")
    var mediaTypes: String = default_mediaTypes
    
    @Option(name: .shortAndLong, help: "Limit fetch requests to at most this many results. Default: 0 <unlimited>")
    var fetchLimit: Int?
    
    @Option(name: .shortAndLong, help: "A DateFormatter format string for use in naming snapshot folders. Default: yyyy-MM-dd_hh-mm-ss")
    var dateFormat: String = default_dateFormat

    @Flag(name: .shortAndLong, help: "Warn if a resource file already exists at the output path. Otherwise this file is treated as a successful download. Default: false")
    var warnExists: Bool = false

    @Flag(name: .shortAndLong, help: "Disable network (iCloud) fetch requests -- only process local assets")
    var localOnly: Bool = false

    @Flag(name: .shortAndLong, help: "Do not include Hidden assets in fetch results")
    var noHidden: Bool = false
        
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
        if let value = env["DATE_FORMAT"] {
             dateFormat = value
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
        if (base != nil && (!append && !incremental)) {
            append = true
        }
        if (append && incremental) {
            // TODO: stderr
            print("Append and incremental operations are mutually exclusive")
            return
        }
        if ((append || incremental) && base == nil) {
            // TODO: stderr
            print("Append and incremental operations require a -b <base> folder")
            return
        }
        if (!uuid.isEmpty && (incremental || mediaTypes != default_mediaTypes)) {
            // TODO: stderr
            print("UUID-based fetches disable incremental operations and media-types filters")
            return
        }
        
        // Start chatting
        if (verbose) {
            print("Verbose output enabled")
        }
               
        // Run it
        try PhotosSnapshot(cmdLineArgs: self).main();
    }
}
