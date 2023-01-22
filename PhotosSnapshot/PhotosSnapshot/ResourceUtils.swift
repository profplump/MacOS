//
//  PhotosUtils.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-18.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class ResourceUtils {
    static func uuid(id: String?) -> String {
        // Return a string even if we are fed nothing
        if (id == nil) {
            return "Invalid_UUID"
        }
        let safeId = id!
        
        // Do something sane even if we don't get a valid assetLocalID
        let slash = safeId.firstIndex(of: "/")
        if (slash == nil) {
            return safeId
        }

        // This UUID matches the one in the Photos Library SQLite DB
        return String(safeId[..<slash!])
    }
    
    static func path(resource: PHAssetResource) -> String {
        /** Grab a stable UUID for this asset bundle **/
        let UUID = ResourceUtils.uuid(id: resource.assetLocalIdentifier)
        
        /** Grab the extension from the original import file **/
        let ext = URL(fileURLWithPath: resource.originalFilename).pathExtension.lowercased()
        
        /** Name the resource type **/
        var type: String
        switch (resource.type) {
        case .photo:
            type = "Photo"
        case .fullSizePhoto:
            type = "Photo - Modified"
        case .alternatePhoto:
            type = "Photo - Alternate"
        case .video:
            type = "Video"
        case .fullSizeVideo:
            type = "Video - Modified"
        case .pairedVideo:
            type = "Live Photo"
        case .fullSizePairedVideo:
            type = "Live Photo - Modified"
        case .audio:
            type = "Audio"
        case .adjustmentData, .adjustmentBasePhoto, .adjustmentBaseVideo, .adjustmentBasePairedVideo:
            fallthrough
        @unknown default:
            // TODO: stderr
            print("Unxpected resource type: \(resource.type.rawValue)")
            type = "Unknown - " + String(resource.type.rawValue)
        }
        
        // Path substring: UUID/Photo.jpg
        return UUID + "/" + type + "." + ext
    }
}
