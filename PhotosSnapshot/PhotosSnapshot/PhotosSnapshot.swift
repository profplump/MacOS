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
    var assetSets: [PHFetchResult<PHAsset>]
    
    init(cmdLineArgs: CmdLineArgs) {
        options = cmdLineArgs
        access = PhotosAccess()
        list = PhotosList(cmdLineArgs: options)
        fetchPaths = FetchPaths(parentFolder: URL(fileURLWithPath: options.parent))
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
            // TODO: stderr
            print("Found 0 media assets")
            exit(-4)
        }
        
        // Fetch to filesystem
        var exitError: Int32 = 0
        let fetch = PhotosFetch(cmdLineArgs: options)
        for assets in assetSets {
            if (options.verbose) {
                print("Fetching \(assets.count) assets")
            }
            let fetchStats = fetch.fetchAssets(media: assets, fetchPaths: fetchPaths)
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
    
    func appendAssets(assets: PHFetchResult<PHAsset>) {
        if (assets.count > 0) {
            assetSets.append(assets)
        }
    }
    
    func buildDestURL() {
        var subFolder = String();
        
        // Setup to print and parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = options.dateFormat
        if (options.verbose) {
            print("Date Format: \(dateFormatter.dateFormat!)")
        }
        
        // Validate the base folder, if provided
        if (options.base != nil) {
            fetchPaths.baseFolder = URL(fileURLWithPath: options.base!, relativeTo: fetchPaths.parentFolder)
            var isDir: ObjCBool = true
            if (!FileManager.default.fileExists(atPath: fetchPaths.baseFolder.path, isDirectory: &isDir)) {
                // TODO: stderr
                print("Base folder does not exist: \(fetchPaths.baseFolder.path)")
                exit(-1)
            }
            if (options.verbose) {
                print("Base Folder: \(fetchPaths.baseFolder.path)")
            }
        }
        
        // Parse a modification date from the base folder date
        if (options.incremental) {
            var compareString: String
            if (options.compareDate != nil) {
                compareString = options.compareDate!
                print("Compare Date: \(options.compareDate!)")
            } else {
                compareString = fetchPaths.baseFolder.lastPathComponent
            }
            fetchPaths.compareDate = dateFormatter.date(from: compareString)
            if (fetchPaths.compareDate == nil) {
                // TODO: stderr
                print("Unable to parse compare date: \(compareString)")
                exit(-1)
            }
            if (options.verbose) {
                print("Incremental Date: \(fetchPaths.compareDate!)")
            }
        }
        
        // Unless we are appending, target a new destination
        if (options.append) {
            subFolder = fetchPaths.baseFolder.lastPathComponent
        } else {
            subFolder = dateFormatter.string(from: Date())
        }

        // Build the URL
        var destURL = fetchPaths.parentFolder
        destURL.append(component: subFolder + "/")
        fetchPaths.destFolder = destURL
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
}
