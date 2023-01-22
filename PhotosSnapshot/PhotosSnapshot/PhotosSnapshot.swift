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
    var parentFolder: URL
    var assetSets: [PHFetchResult<PHAsset>]
    
    init(cmdLineArgs: CmdLineArgs) {
        options = cmdLineArgs
        access = PhotosAccess()
        list = PhotosList(cmdLineArgs: options)
        parentFolder = URL(fileURLWithPath: options.parent)
        assetSets = []
    }

    func main() throws {
        // Prompt for Photo Library access and wait until we have it
        access.auth(wait: true)
        if (!access.valid()) {
            exit(-3)
        }
        
        // Figure out where we are writing
        let destFolder = buildDestURL()
        if (options.verbose) {
            print("Writing to folder: \(destFolder)")
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
        var date = String();
        if (options.base != nil) {
            if (options.append) {
                if (options.verbose) {
                    print("Appending to folder: \(options.base!)")
                }
                date = options.base!
            } else if (options.incremental) {
                print("Not yet implemented")
                exit(-5)
            }
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            dateFormatter.dateFormat = options.dateFormat
            if (options.verbose) {
                print("Using date format string: \(dateFormatter.dateFormat!)")
            }
            date = dateFormatter.string(from: Date())
        }
        return URL(fileURLWithPath: parentFolder.path + "/" + date + "/")
    }
    
    func buildMediaTypes() -> [ PHAssetMediaType: Bool ]  {
        // User-specified media types
        var mediaTypes: [ PHAssetMediaType: Bool ] = [ PHAssetMediaType: Bool ]()
        if (options.verbose) {
            print("Select media types: \(options.mediaTypes)")
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
        /**
        let assets = list.media(mediaType: mediaType, oldestDate: Date(timeIntervalSinceNow: -86400))
        for i in 0...assets.count-1 {
            let asset = assets.object(at: i)
            print("Asset: \(Utils.uuid(id: asset.localIdentifier))")
            print("\tCreated: \(String(describing: asset.creationDate))")
            print("\tModified: \(String(describing: asset.modificationDate))")
        }
         **/
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
