//
//  AssetResource.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-24.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class AssetResource {
    var asset: PHAsset
    var resource: PHAssetResource
    var uuid: String
    var filename: String
    var compareDate: Date?
    var changed: Bool?
    
    init(asset: PHAsset, resource: PHAssetResource, compareDate: Date? = nil) {
        self.asset = asset
        self.resource = resource
        self.compareDate = compareDate
        uuid = AssetResource.uuid(id: resource.assetLocalIdentifier)
        filename = AssetResource.path(resource: resource)
    }
    
    func outdated() -> Bool {
        if (compareDate == nil) {
            print("AssetResource.outdated() called with no compareDate")
        }
        if (changed == nil && compareDate != nil) {
            changed = (max(asset.creationDate ?? Date.distantFuture, asset.modificationDate ?? Date.distantFuture) >= compareDate ?? Date.now)
        }
        return changed!
    }
    
    static func uuid(id: String?) -> String {
        // Return a UUID string even if we are fed nothing
        if (id == nil || id!.isEmpty) {
            return "INVALID_" + UUID().uuidString
        }
        let safeId = id!
        
        // Do something sane even if we don't get the usual assetLocalID
        let slash = safeId.firstIndex(of: "/")
        if (slash == nil) {
            return safeId
        }

        // This UUID matches the one in the Photos Library SQLite DB
        return String(safeId[..<slash!])
    }
    
    static func path(resource: PHAssetResource) -> String {
        // Grab a stable UUID for this asset
        let UUID = uuid(id: resource.assetLocalIdentifier)
        
        // Grab the extension from the original import file
        let ext = URL(fileURLWithPath: resource.originalFilename).pathExtension.lowercased()
        
        // Name the resource type
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
            print("Unxpected resource type: \(resource.type.rawValue)")
            type = "Unknown - " + String(resource.type.rawValue)
        }
        
        // Path substring: UUID_000DESTRUCT0/Photo.jpg
        return UUID + "/" + type + "." + ext
    }
}
