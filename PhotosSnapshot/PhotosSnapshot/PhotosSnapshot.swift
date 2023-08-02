//
//  PhotosSnapshot.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-19.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class PhotosSnapshot {
    
    enum Mode { case SNAPSHOT, INCREMENTAL, VERIFY }

    let options: CmdLineArgs
    let access: PhotosAccess
    let list: PhotosList
    let fetchPaths: FetchPaths
    let dateFormatter: DateFormatter
    var assetSets: [PHFetchResult<PHAsset>]
    var mode: Mode
    
    init(options: CmdLineArgs) {
        self.options = options
        access = PhotosAccess()
        list = PhotosList(cmdLineArgs: options)
        fetchPaths = FetchPaths(parentFolder: URL(fileURLWithPath: options.parent))
        dateFormatter = PhotosSnapshot.dateFormatterFactory(options: options)
        assetSets = []
        
        // Determine what we are doing
        if (options.clone != nil || options.hardlink != nil || options.symlink != nil) {
            mode = Mode.INCREMENTAL
        } else if (options.verify != nil) {
            mode = Mode.VERIFY
        } else {
            mode = Mode.SNAPSHOT
        }
    }

    func main() {
        // Prompt for Photo Library access and wait until we have it
        access.auth(wait: true)
        if (!access.valid()) {
            exit(-3)
        }
        
        // Figure out where we are writing
        buildDestURL()
        if (options.verbose) {
            print("\(mode)ing to: \(fetchPaths.destFolder.path)")
        }
        
        // Make sure the filesystem supports our plans
        if (mode == Mode.INCREMENTAL) {
            do {
                let volCapabilities = try fetchPaths.parentFolder.resourceValues(forKeys: [ .volumeSupportsSymbolicLinksKey, .volumeSupportsHardLinksKey, .volumeSupportsFileCloningKey])
                if (options.clone != nil && !volCapabilities.volumeSupportsFileCloning!) {
                    print("Clone requested but volume does not support clonefile()")
                    return
                } else if (options.hardlink != nil && !volCapabilities.volumeSupportsHardLinks!) {
                    print("Hardlink requested but volume does not support hardlinks")
                    return
                } else if (options.symlink != nil && !volCapabilities.volumeSupportsSymbolicLinks!) {
                    print("Symlink requested but volume does not support symlinks")
                    return
                }
            } catch {
                print("Error determining volume support for thin copies: \(error)")
                return
            }
        }
        
        // Parse the baseFolder and compareDate
        if (mode == Mode.VERIFY) {
            validateBaseURL(base: options.verify!)
        } else if (mode == Mode.INCREMENTAL) {
            var base: String = ""
            if (options.clone != nil) {
                base = options.clone!
            } else if (options.hardlink != nil) {
                base = options.hardlink!
            } else if (options.symlink != nil) {
                base = options.symlink!
            }
            validateBaseURL(base: base)
        }
        let compareDate = parseCompareDate()
        
        // Figure out what assets we are fetching
        let mediaTypes = buildMediaTypes()
        if (!options.uuid.isEmpty) {
            // Find assets with provided assetLocalIDs (i.e. ZUUIDs)
            processUUIDs(uuids: options.uuid)
        } else {
            // List all enabled assets
            mediaTypes.forEach { (key: PHAssetMediaType, value: Bool) in
                if (value) {
                    processAssets(mediaType: key)
                }
            }
        }
        if (assetSets.count < 1) {
            print("Found 0 media assets")
            exit(-4)
        }
        
        // Fetch
        var exitError: Int32 = 0
        for assets in assetSets {
            let fetch = PhotosFetch(cmdLineArgs: options, fetchPaths: fetchPaths, compareDate: compareDate)
            if (options.verbose) {
                print("Fetching \(assets.count) assets")
            }
            let fetchStats = fetch.fetchAssets(media: assets)
            if (options.verbose) {
                print("Resources: \(fetchStats.resourceSuccess.count)/\(fetchStats.resourceError.count) success/failure")
            }
            print("Fetched \(fetchStats.assetSuccess.count) of \(assets.count) assets with \(fetchStats.assetError.count) errors")
            if (fetchStats.assetError.count > 0) {
                exitError = 100
                print("Incomplete assets:")
                for error in fetchStats.assetError.sorted() {
                    print("\t\(error)")
                }
            }
        }
        
        // Exit 0 if there were no errors, otherwise 100
        exit(exitError)
    }
    
    func parseCompareDate() -> Date? {
        var compareDate: Date? = nil
        // Parse a modification date from the base folder date
        if (mode == Mode.INCREMENTAL || mode == Mode.VERIFY) {
            var compareString: String
            if (options.compareDate != nil) {
                compareString = options.compareDate!
                if (options.verbose) {
                    print("Compare String: \(compareString)")
                }
            } else {
                compareString = fetchPaths.baseFolder.lastPathComponent
            }
            compareDate = dateFormatter.date(from: compareString)
            if (compareDate == nil) {
                print("Unable to parse compare date: \(compareString)")
                exit(-1)
            }
            if (options.verbose) {
                print("Compare Date: \(compareDate!)")
            }
        }
        
        return compareDate
    }
    
    func findMostRecent(parentFolder: URL) -> URL {
        var names: Set<String> = []
        do {
            // Find folders under parentFolder
            let folders = try FileManager.default.contentsOfDirectory(at: parentFolder, includingPropertiesForKeys: [URLResourceKey.isDirectoryKey])
            for folder in folders {
                let isDir = try folder.resourceValues(forKeys: [.isDirectoryKey])
                if (isDir.isDirectory!) {
                    names.insert(folder.lastPathComponent)
                }
            }
        } catch {
            print("Unable to read contents of parent folder: \(parentFolder.path)")
            exit(-1)
        }
        
        // Parse what we can into URLs and dates
        var snapshots: [Date: URL] = [:]
        for name in names {
            let snapshotDate = dateFormatter.date(from: name)
            if (snapshotDate == nil) {
                if (options.verbose) {
                    print("Unable to parse snapshot date from: \(name)")
                }
            } else {
                let snapshotURL = URL(fileURLWithPath: name, relativeTo: parentFolder)
                snapshots.updateValue(snapshotURL, forKey: snapshotDate!)
            }
        }
        // Find the most recent
        if (!snapshots.isEmpty) {
            let latest = snapshots.keys.sorted().last!
            if (options.verbose) {
                print("Latest Snapshot: \(latest)")
            }
            return snapshots[latest]!
        } else {
            print("Unable to find a recent snapshot in: \(parentFolder.path)")
            exit(-1)
        }
    }
    
    func validateBaseURL(base: String) {
        if (base == "RECENT") {
            fetchPaths.baseFolder = findMostRecent(parentFolder: fetchPaths.parentFolder)
        } else {
            fetchPaths.baseFolder = URL(fileURLWithPath: base, relativeTo: fetchPaths.parentFolder)
        }
        
        var isDir: ObjCBool = true
        if (!FileManager.default.fileExists(atPath: fetchPaths.baseFolder.path, isDirectory: &isDir)) {
            print("Base folder does not exist: \(fetchPaths.baseFolder.path)")
            exit(-1)
        }
        if (options.verbose) {
            print("Base Folder: \(fetchPaths.baseFolder.path)")
        }
    }
    
    func buildDestURL() {
        // Use a temp path if we are verifying
        if (options.verify != nil) {
            fetchPaths.destFolder = FileManager.default.temporaryDirectory.appendingPathComponent("PhotosSnapshot/", isDirectory: true)
            return
        }
        
        // Create a new folder unless we are appending
        if (options.append != nil) {
            if (options.append == "RECENT") {
                fetchPaths.destFolder = findMostRecent(parentFolder: fetchPaths.parentFolder)
            } else {
                fetchPaths.destFolder = fetchPaths.parentFolder.appendingPathComponent(options.append!, isDirectory: true)
            }
        } else {
            fetchPaths.destFolder = fetchPaths.parentFolder.appendingPathComponent(dateFormatter.string(from: Date()), isDirectory: true)
        }
        
        // Verify that the destFolder exists (or doesn't exist) like we expect
        var isDir: ObjCBool = true
        let exists: Bool = FileManager.default.fileExists(atPath: fetchPaths.destFolder.path, isDirectory: &isDir)
        var error: String? = nil
        if (exists && options.append == nil) {
            error = "Subfolder exists"
        } else if (!exists && options.append != nil) {
            error = "Invalid append folder"
        }
        if (error != nil) {
            print("\(error!): \(fetchPaths.destFolder.path)")
            exit(-1)
        }
    }
    
    func buildMediaTypes() -> [ PHAssetMediaType: Bool ]  {
        // User-specified media types
        var mediaTypes: [ PHAssetMediaType: Bool ] = [ PHAssetMediaType: Bool ]()
        if (options.verbose) {
            print("Media types: \(options.mediaTypes)")
        }
        if (options.mediaTypes.firstIndex(of: "A") != nil)  {
            mediaTypes[.audio] = true
        }
        if (options.mediaTypes.firstIndex(of: "P") != nil)  {
            mediaTypes[.image] = true
        }
        if (options.mediaTypes.firstIndex(of: "V") != nil) {
            mediaTypes[.video] = true
        }
        return mediaTypes
    }
    
    func processAssets(mediaType: PHAssetMediaType) {
        if (options.verbose) {
            print("Listing type \(mediaType.rawValue) assets")
        }
        let assets = list.media(mediaType: mediaType)
        appendAssets(assets: assets)
        if (options.verbose) {
            print("Found \(assets.count) type \(mediaType.rawValue) assets")
        }
    }
    
    func processUUIDs(uuids: [String]) {
        if (options.verbose) {
            print("Listing assets by UUID")
        }
        let assets = list.assetByLocalID(uuids: uuids)
        appendAssets(assets: assets)
        if (options.verbose) {
            print("Found \(assets.count) UUID assets")
        }
    }
    
    fileprivate func appendAssets(assets: PHFetchResult<PHAsset>) {
        if (assets.count > 0) {
            assetSets.append(assets)
        }
    }
    
    fileprivate static func dateFormatterFactory(options: CmdLineArgs) -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = options.dateFormat
        if (options.verbose) {
            print("Date Format: \(df.dateFormat!)")
        }
        return df
    }
}
