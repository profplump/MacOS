//
//  PhotosFetch.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-18.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class PhotosFetch {
    private let resourceManager: PHAssetResourceManager
    private let photosUtils: PhotosUtils
        
    init() {
        resourceManager = PHAssetResourceManager()
        photosUtils = PhotosUtils()
    }
    
    fileprivate func fetchOptions() -> PHAssetResourceRequestOptions {
        let fetchOptions = PHAssetResourceRequestOptions()
        fetchOptions.isNetworkAccessAllowed = true
        return fetchOptions
    }
    
    func fetchAssets(media: PHFetchResult<PHAsset>, parentFolder: URL) async {
        var assetCount: Int = 0
        var resourceCount: Int = 0
        var errorCount: Int = 0

        // Override max for testing
        let max = min(media.count, 25)
        for i in 0...max-1 {
            let asset = media.object(at: i)
            let resources = PHAssetResource.assetResources(for: asset)

            let valid = findValidResources(resources: resources)
            if (valid.count < 1) {
                print("No valid resources for asset: \(PhotosUtils.uuid(id: asset.localIdentifier))")
                continue
            }

            for resource in valid {
                do {
                    try await readFile(resource: resource, parentFolder: parentFolder)
                    resourceCount += 1
                } catch {
                    print("Failed to fetch: \(PhotosUtils.uuid(id: resource.assetLocalIdentifier)).\(resource.type.rawValue)")
                    errorCount += 1
                }
            }
            assetCount += 1
        }
        
        print("Assets: \(assetCount)")
        print("Resources: \(resourceCount)")
        print("Errors: \(errorCount)")
    }
    
    func readFile(resource: PHAssetResource, parentFolder: URL) async throws {
        let filename = photosUtils.resourcePath(resource: resource)
        let dest = URL(fileURLWithPath: filename, relativeTo: parentFolder)
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)

        /** Do not overwrite **/
        if (FileManager.default.fileExists(atPath: dest.path)) {
            //try FileManager.default.removeItem(at: dest)
            print("Skipping write to existing file: \(dest)")
            return
        }

        try await resourceManager.writeData(for: resource, toFile: dest, options: fetchOptions())
    }
    
    func findValidResources(resources: [PHAssetResource]) -> [PHAssetResource] {
        var valid: [PHAssetResource] = []
        
        // Images
        valid.append(contentsOf: validateResources(resources: resources, originalType: PHAssetResourceType.photo, modifiedType: PHAssetResourceType.fullSizePhoto))
        
        // Alternate Images
        valid.append(contentsOf: validateResources(resources: resources, originalType: PHAssetResourceType.alternatePhoto))
        
        // Live Photos
        valid.append(contentsOf: validateResources(resources: resources, originalType: PHAssetResourceType.pairedVideo, modifiedType: PHAssetResourceType.fullSizePairedVideo))
       
        // Videos
        valid.append(contentsOf: validateResources(resources: resources, originalType: PHAssetResourceType.video, modifiedType: PHAssetResourceType.fullSizeVideo))

        // Audio
        valid.append(contentsOf: validateResources(resources: resources, originalType: PHAssetResourceType.audio))
                 
        return valid
    }
    
    func validateResources(resources: [PHAssetResource], originalType: PHAssetResourceType, modifiedType: PHAssetResourceType? = nil) -> [PHAssetResource] {
        let id = resources.first?.assetLocalIdentifier ?? "<missing ID>"

        var valid: [PHAssetResource] = []
        let original = resources.filter { $0.type == originalType }
        var modified: [PHAssetResource] = []
        if (modifiedType != nil) {
            modified = resources.filter { $0.type == modifiedType }
        }

        if (original.count > 0 ||  modified.count > 0) {
            if (original.count == 1) {
                valid.append(original.first!)
            } else {
                print("No original resource: \(id)")
            }
            if (modified.count > 0) {
                valid.append(modified.first!)
                if (modified.count > 1) {
                    print("Invalid modified resources: \(id)")
                }
            }
        }
        
        return valid
    }
}
