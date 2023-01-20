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

    // Prompt for Photo Library access and wait until we have it
    func main() async throws {
        access.auth(wait: true)
        if (!access.valid()) {
            exit(-3)
        }
        
        // Figure out where we are writing
        validateParentURL()
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
            processUUIDs(args: CommandLine.arguments)
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
            // I should probably queue these for faster dispatch, but for now, await
            let fetchStats = await fetch.fetchAssets(media: assets, destFolder: destFolder)
            print("Assets: \(fetchStats.assetCount)/\(fetchStats.assetErrors) success/error")
            print("Resources: \(fetchStats.resourceCount)/\(fetchStats.resourceErrors) success/error")
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
    
    func validateParentURL() {
        if (CommandLine.arguments.count > 1) {
            parentFolder = URL(fileURLWithPath: CommandLine.arguments[1])
        } else {
            usage() // Does not return
        }
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
        let assets = list.media(mediaType: mediaType)
        safeAppendAssetSets(assets: assets)
        print("Found \(assets.count) type \(mediaType.rawValue) assets")
    }
    
    func processUUIDs(args: [String]) {
        var uuids: [String] = []
        for i in 2...args.count-1 {
            uuids.append(args[i])
        }
        print("Processing \(uuids.count) UUIDs")
        let assets = list.assetByLocalID(uuids: uuids)
        safeAppendAssetSets(assets: assets)
        print("Found \(assets.count) UUID assets")
    }
    
    fileprivate func usage() {
        print("Usage: \(CommandLine.arguments.first ?? "<cmd>")) output_folder [UUID1] [UUID2]")
        exit(-1)
    }
}
