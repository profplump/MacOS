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
    private let fetchOptions: PHAssetResourceRequestOptions
    private let resourceManager: PHAssetResourceManager
        
    init() {
        resourceManager = PHAssetResourceManager()

        fetchOptions = PHAssetResourceRequestOptions()
        if (ProcessInfo.processInfo.environment.index(forKey: "NO_NETWORK") != nil) {
            print("Excluding network assets")
            fetchOptions.isNetworkAccessAllowed = false
        } else {
            fetchOptions.isNetworkAccessAllowed = true
        }
    }
    
    func fetchAssets(media: PHFetchResult<PHAsset>, parentFolder: URL) async {
        var assetCount: Int = 0
        var resourceCount: Int = 0
        var errorCount: Int = 0

        // Fetch valid (usable) resources of every asset
        for i in 0...media.count-1 {
            let asset = media.object(at: i)
            let startResourceCount = resourceCount

            let resources = PHAssetResource.assetResources(for: asset)
            for resource in findValidResources(resources: resources) {
                do {
                    try await readFile(resource: resource, parentFolder: parentFolder)
                    resourceCount += 1
                } catch {
                    print("Resource fetch error: \(Utils.resourcePath(resource: resource))")
                    errorCount += 1
                }
            }
            
            // Notice if we did not fetch any resources for this asset
            if (startResourceCount == resourceCount) {
                print("Fetched 0 resources for asset: \(Utils.uuid(id: asset.localIdentifier))")
                continue
            }
            assetCount += 1
        }
        
        // Error statistics so we can tell how things went
        print("Assets: \(assetCount)/\(media.count - assetCount) success/error")
        print("Resources: \(resourceCount)/\(errorCount) success/error")
    }
    
    func readFile(resource: PHAssetResource, parentFolder: URL) async throws {
        let filename = Utils.resourcePath(resource: resource)
        let dest = URL(fileURLWithPath: filename, relativeTo: parentFolder)
        try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)

        /** Do not overwrite **/
        if (FileManager.default.fileExists(atPath: dest.path)) {
            if (ProcessInfo.processInfo.environment.index(forKey: "WARN_EXISTS") != nil) {
                print("File exists: \(dest)")
            }
            return
        }
        try await resourceManager.writeData(for: resource, toFile: dest, options: fetchOptions)
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
