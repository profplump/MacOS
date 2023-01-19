//
//  main.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-17.
//

import Foundation
import Photos

// Prompt for Photo Library access and wait until we have it
let access = PhotosAccess()
access.auth(wait: true)
if (!access.valid()) {
    exit(-1)
}

// Figure out where we are writing
var outputFolder = URL(fileURLWithPath:"PhotosSnapshot", relativeTo: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first)
if (CommandLine.arguments.count > 1) {
    outputFolder = URL(fileURLWithPath: CommandLine.arguments[1])
}
var isDir: ObjCBool = true
if (!FileManager.default.fileExists(atPath: outputFolder.path, isDirectory: &isDir)) {
    print("Invalid output folder: \(outputFolder)")
    exit(-3)
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
let parentFolder = URL(fileURLWithPath: outputFolder.path + "/" + date + "/")
print("Writing to folder: \(parentFolder)")
try FileManager.default.createDirectory(at: parentFolder, withIntermediateDirectories: false)

// Figure out which media types we are listing
var saveVideos: Bool = false
var savePhotos: Bool = false
if let value = ProcessInfo.processInfo.environment["MEDIA_TYPES"] {
    // User-specified media types
    print("Media types: \(value)")
    if (value.uppercased().firstIndex(of: "V") != nil) {
        saveVideos = true
    }
    if (value.uppercased().firstIndex(of: "P") != nil)  {
        savePhotos = true
    }
} else {
    // Default behavior
    savePhotos = true
    saveVideos = true
}

// Figure out what assets we are fetching
let list = PhotosList()
var assetSets: [PHFetchResult<PHAsset>] = []
if (CommandLine.arguments.count > 2) {
    // Allow processing of specific assetLocalIDs
    var uuids: [String] = []
    for i in 2...CommandLine.arguments.count-1 {
        uuids.append(CommandLine.arguments[i])
    }
    let uuidAssets = list.assetByLocalID(uuids: uuids)
    if (uuidAssets.count > 0) {
        assetSets.append(uuidAssets)
    }
} else {
    // List all photo and video assets
    if (savePhotos) {
        let photos = list.photos()
        if (photos.count > 0) {
            assetSets.append(photos)
        }
        print("Found \(photos.count) photo assets")
    }
    if (saveVideos) {
        let videos = list.media(mediaType: .video)
        if (videos.count > 0) {
            assetSets.append(videos)
        }
        print("Found \(videos.count) video assets")
    }
}
if (assetSets.count < 1) {
    print("Found 0 media assets")
    exit(-2)
}

// Fetch to filesystem
let fetch = PhotosFetch()
for assets in assetSets {
    print("Fetching \(assets.count) assets")
    // I should probably queue these for faster dispatch, but for now, await
    await fetch.fetchAssets(media: assets, parentFolder: parentFolder)
}
