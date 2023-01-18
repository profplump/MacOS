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
    exit(-1);
}

let list = PhotosList()

let photos = list.photos()
print("Photos: \(photos.count)")

let videos = list.media(mediaType: .video)
print("Videos: \(videos.count)")

if (photos.count < 1) {
    print("Found 0 photos")
    exit(-2)
}

let fetch = PhotosFetch()
let parentFolder = URL(fileURLWithPath: "Foo/", relativeTo: FileManager.default.homeDirectoryForCurrentUser)
await fetch.fetchAssets(media: photos, parentFolder: parentFolder)
