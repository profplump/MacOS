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
    var oldestDate: Date?
    var parentFolder: URL
    var assetSets: [PHFetchResult<PHAsset>]
    
    init(cmdLineArgs: CmdLineArgs) {
        options = cmdLineArgs
        access = PhotosAccess()
        list = PhotosList(cmdLineArgs: options)
        parentFolder = URL(fileURLWithPath: options.parent)
        parentFolder.standardize()
        assetSets = []
        oldestDate = nil
    }

    func main() {
        // Prompt for Photo Library access and wait until we have it
        access.auth(wait: true)
        if (!access.valid()) {
            exit(-3)
        }
        
        // Figure out where we are writing
        let destFolder = buildDestURL()
        if (options.verbose) {
            var operation: String
            if (options.append) {
                operation = "append"
            } else if (options.incremental) {
                operation = "incremental"
            } else {
                operation = "snapshot"
            }
            print("\(operation.localizedCapitalized)ing to: \(destFolder)")
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
            let fetchStats = fetch.fetchAssets(media: assets, destFolder: destFolder)
            if (options.verbose) {
                print("Resources: \(fetchStats.resourceSuccess.count)/\(fetchStats.resourceError.count) success/fail")
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
    
    func buildDestURL() -> URL {
        var subFolder = String();
        
        // Setup to print and parse dates
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.dateFormat = options.dateFormat
        if (options.verbose) {
            print("Date Format: \(dateFormatter.dateFormat!)")
        }
        
        // Validate the base folder, if provided
        var baseURL: URL
        if (options.base != nil) {
            baseURL = URL(fileURLWithPath: options.base!, relativeTo: parentFolder)
            var isDir: ObjCBool = true
            if (!FileManager.default.fileExists(atPath: baseURL.path, isDirectory: &isDir)) {
                // TODO: stderr
                print("Base folder does not exist: \(baseURL)")
                exit(-1)
            }
        } else {
            // This isn't used but it saves a lot of ! and ?
            baseURL = URL(fileURLWithPath: "")
        }
        
        // Parse a modification date from the base folder date
        if (options.incremental) {
            if (options.compareDate != nil) {
                oldestDate = dateFormatter.date(from: options.compareDate!)
                if (options.verbose) {
                    print("Compare Date: \(options.compareDate!)")
                }
            } else {
                oldestDate = dateFormatter.date(from: baseURL.lastPathComponent)
            }
            if (oldestDate == nil) {
                // TODO: stderr
                print("Unable to parse subfolder datetime: \(baseURL.lastPathComponent)")
                exit(-1)
            }
            if (options.verbose) {
                print("Incremental Date: \(oldestDate!)")
            }

            print("")
            print("Incremental: Work in progress. Currently this operation only checks the asset create/modified timestamp, not individual resource timestamps")
            if (options.clone || options.hardlink || options.symlink) {
                print("Thin snapshots using --clone, --hardlink, or --symlink are not yet implemented.")
                print("Reverting to --incremental operation")
            }
            print("")
        }
        
        // Unless we are appending, target a new destination
        if (options.append) {
            subFolder = baseURL.lastPathComponent
        } else {
            subFolder = dateFormatter.string(from: Date())
        }

        // Build the URL
        var destURL = parentFolder
        destURL.append(component: subFolder + "/")
        return destURL
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
        var listDate: Date?
        if (options.incremental && !(options.clone || options.hardlink || options.symlink)) {
            // Only restrict the list step when we are doing a non-linked incremental snapshot
            listDate = oldestDate
        } else {
            // Otherwise fetch everything and filter the resources directly
            listDate = nil
        }
        let assets = list.media(mediaType: mediaType, oldestDate: listDate)
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
