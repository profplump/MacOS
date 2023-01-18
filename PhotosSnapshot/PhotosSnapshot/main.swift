//
//  main.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-17.
//

import Foundation
import Photos

// Prompt for access and wait until we have it
let access = PhotosAccess()
access.auth(wait: true)
if (!access.valid()) {
    exit(-1)
}

// List all our image and video assets
let list = PhotosList()
let photos = list.photos()
let videos = list.media(mediaType: .video)
if (photos.count + videos.count < 1) {
    print("Found 0 media assets")
    exit(-2)
}

// Figure out where we are writing
var outputFolder = URL(fileURLWithPath:"hi", relativeTo: FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first)
if (CommandLine.arguments.count > 1) {
    outputFolder = URL(fileURLWithPath: CommandLine.arguments[1])
}
var isDir: ObjCBool = true
if (!FileManager.default.fileExists(atPath: outputFolder.path, isDirectory: &isDir)) {
    print("Invalid output folder: \(outputFolder)")
    exit(-3)
}
let dateFormatter = DateFormatter()
dateFormatter.locale = Locale(identifier: "en_US_POSIX")
dateFormatter.dateFormat = "yyyy-MM-dd_HH-mm-ss"
let parentFolder = URL(fileURLWithPath: outputFolder.path + "/" + dateFormatter.string(from: Date()) + "/")
print("Writing to folder: \(parentFolder)")
try FileManager.default.createDirectory(at: parentFolder, withIntermediateDirectories: true)

// Fetch to filesystem
let fetch = PhotosFetch()
print("Fetching \(photos.count) photos")
await fetch.fetchAssets(media: photos, parentFolder: parentFolder)
print("Fetching \(videos.count) videos")
await fetch.fetchAssets(media: videos, parentFolder: parentFolder)
