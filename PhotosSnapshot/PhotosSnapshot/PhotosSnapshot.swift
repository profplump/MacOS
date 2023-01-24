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
    
    let options: CmdLineArgs
    let access: PhotosAccess
    let list: PhotosList
    let fetchPaths: FetchPaths
    let dateFormatter: DateFormatter
    var assetSets: [PHFetchResult<PHAsset>]
    
    init(options: CmdLineArgs) {
        self.options = options
        access = PhotosAccess()
        list = PhotosList(cmdLineArgs: options)
        fetchPaths = FetchPaths(parentFolder: URL(fileURLWithPath: options.parent))
        dateFormatter = PhotosSnapshot.dateFormatterFactory(options: options)
        assetSets = []
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
            var operation: String
            if (options.append) {
                operation = "append"
            } else if (options.incremental) {
                operation = "incremental"
            } else if (options.verify) {
                operation = "verify"
            } else {
                operation = "snapshot"
            }
            print("\(operation.localizedCapitalized)ing to: \(fetchPaths.destFolder)")
        }
        
        // Make sure the filesystem supports our plans
        do {
            let volCapabilities = try fetchPaths.parentFolder.resourceValues(forKeys: [ .volumeSupportsSymbolicLinksKey, .volumeSupportsHardLinksKey, .volumeSupportsFileCloningKey])
            if (options.clone && !volCapabilities.volumeSupportsFileCloning!) {
                print("Clone requested but volume does not support clonefile()")
                return
            } else if (options.hardlink && !volCapabilities.volumeSupportsHardLinks!) {
                print("Hardlink requested but volume does not support hardlinks")
                return
            } else if (options.symlink && !volCapabilities.volumeSupportsSymbolicLinks!) {
                print("Symlink requested but volume does not support symlinks")
                return
            }
        } catch {
            print("Error determining volume support for thin copies: \(error)")
            return
        }
        
        // Parse the baseFolder and compareDate
        validateBaseURL()
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
        
        // Fetch to filesystem
        var exitError: Int32 = 0
        let fetch = PhotosFetch(cmdLineArgs: options, fetchPaths: fetchPaths, compareDate: compareDate)
        for assets in assetSets {
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
        if (options.incremental || options.verify) {
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
    
    func validateBaseURL() {
        if (options.base == nil) {
            return
        }
        if (options.base == "RECENT") {
            print("Base folder 'RECENT' is not supported. Yet.")
            exit(-5)
        } else {
            fetchPaths.baseFolder = URL(fileURLWithPath: options.base!, relativeTo: fetchPaths.parentFolder)
            var isDir: ObjCBool = true
            if (!FileManager.default.fileExists(atPath: fetchPaths.baseFolder.path, isDirectory: &isDir)) {
                print("Base folder does not exist: \(fetchPaths.baseFolder.path)")
                exit(-1)
            }
            if (options.verbose) {
                print("Base Folder: \(fetchPaths.baseFolder.path)")
            }
        }
    }
    
    func buildDestURL() {
        // Only append re-uses a snapshot destination
        var subFolder = String();
        if (options.append) {
            subFolder = fetchPaths.baseFolder.lastPathComponent
        } else {
            subFolder = dateFormatter.string(from: Date())
        }

        // Use a temp path if we are verifying
        if (options.verify) {
            fetchPaths.destFolder = FileManager.default.temporaryDirectory.appendingPathComponent("PhotosSnapshot/" + subFolder, isDirectory: true)
        } else {
            fetchPaths.destFolder = fetchPaths.parentFolder.appendingPathComponent(subFolder, isDirectory: true)
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
    
    fileprivate static func dateFormatterFactory(options: CmdLineArgs) -> DateFormatter {
        let df = DateFormatter()
        df.locale = Locale(identifier: "en_US_POSIX")
        df.dateFormat = options.dateFormat
        if (options.verbose) {
            print("Date Format: \(df.dateFormat!)")
        }
        return df
    }
    
    fileprivate func appendAssets(assets: PHFetchResult<PHAsset>) {
        if (assets.count > 0) {
            assetSets.append(assets)
        }
    }
}
