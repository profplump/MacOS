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
    
    let access: PhotosAccess
    let list: PhotosList
    var parentFolder: URL
    var destFolder: URL
    var mediaTypes: [ PHAssetMediaType: Bool ]
    var assetSets: [PHFetchResult<PHAsset>]
    
    init() {
        access = PhotosAccess()
        list = PhotosList()
        parentFolder = URL(fileURLWithPath:"PhotosSnapshot", relativeTo: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first)
        destFolder = URL(fileURLWithPath: "", relativeTo: parentFolder)
        mediaTypes = [.audio: true, .image: true, .video: true]
        assetSets = []
    }

    func main() throws {
        // Basic runtime sanity checks
        if (CommandLine.arguments.count < 1) {
            usage() // Does not return
        }

        // Prompt for Photo Library access and wait until we have it
        access.auth(wait: true)
        if (!access.valid()) {
            exit(-3)
        }
        
        // Figure out where we are writing
        validateParentURL(path: CommandLine.arguments[1])
        buildDestURL()
        var isDir: ObjCBool = true
        if (!FileManager.default.fileExists(atPath: parentFolder.path, isDirectory: &isDir)) {
            try FileManager.default.createDirectory(at: destFolder, withIntermediateDirectories: false)
        }
        print("Writing to folder: \(destFolder)")
        
        // Figure out what assets we are fetching
        selectMediaTypes()
        if (CommandLine.arguments.count > 2) {
            // Find assets with provided assetLocalIDs (i.e. ZUUIDs)
            processUUIDs(uuids: Array(CommandLine.arguments.suffix(from: 2)))
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
        let fetch = PhotosFetch()
        for assets in assetSets {
            print("Fetching \(assets.count) assets")
            let fetchStats = fetch.fetchAssets(media: assets, destFolder: destFolder)
            print("Resources: \(fetchStats.resourceSuccess.count)/\(fetchStats.resourceError.count) success/fail")
            print("Fetched \(fetchStats.assetSuccess.count) of \(assets.count) assets with \(fetchStats.assetError.count) errors")
            if (fetchStats.assetError.count > 0) {
                print("Incomplete assets:")
                for error in fetchStats.assetError.sorted() {
                    print("\t\(error)")
                }
            }
        }
    }
    
    func safeAppendAssetSets(assets: PHFetchResult<PHAsset>) {
        if (assets.count > 0) {
            assetSets.append(assets)
        }
    }
    
    func buildDestURL() {
        if (ProcessInfo.processInfo.environment.index(forKey: "NO_SUBFOLDER") != nil) {
            destFolder = parentFolder
            return
        }

        var date = String();
        if let value = ProcessInfo.processInfo.environment["DATE_STRING"] {
            print("Using fixed date string \(value)")
            date = value
        } else {
            let dateFormatter = DateFormatter()
            dateFormatter.locale = Locale(identifier: "en_US_POSIX")
            if let value = ProcessInfo.processInfo.environment["DATE_FORMAT"] {
                print("Using date format string: \(value)")
                dateFormatter.dateFormat = value
            } else {
                dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
            }
            date = dateFormatter.string(from: Date())
        }
        destFolder = URL(fileURLWithPath: parentFolder.path + "/" + date + "/")
    }
    
    func validateParentURL(path: String) {
        parentFolder = URL(fileURLWithPath: path)
        var isDir: ObjCBool = true
        if (!FileManager.default.fileExists(atPath: parentFolder.path, isDirectory: &isDir)) {
            print("Invalid output folder: \(parentFolder)")
            exit(-2)
        }
    }
    
    func selectMediaTypes() {
        if let value = ProcessInfo.processInfo.environment["MEDIA_TYPES"] {
            // User-specified media types
            print("Media types: \(value)")
            mediaTypes = [.audio: false, .image: false, .video: false]
            if (value.uppercased().firstIndex(of: "A") != nil)  {
                mediaTypes[.audio] = true
            }
            if (value.uppercased().firstIndex(of: "P") != nil)  {
                mediaTypes[.image] = true
            }
            if (value.uppercased().firstIndex(of: "V") != nil) {
                mediaTypes[.video] = true
            }
        }
    }
    
    func processAssets(mediaType: PHAssetMediaType) {
        print("Listing type \(mediaType.rawValue) assets")
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
        safeAppendAssetSets(assets: assets)
        print("Found \(assets.count) type \(mediaType.rawValue) assets")
    }
    
    func processUUIDs(uuids: [String]) {
        print("Listing assets by UUID")
        let assets = list.assetByLocalID(uuids: uuids)
        safeAppendAssetSets(assets: assets)
        print("Found \(assets.count) UUID assets")
    }
    
    fileprivate func usage() {
        print("Usage: PhotosSnapshot output_folder [UUID1] [UUID2]")
        exit(-1)
    }
}
