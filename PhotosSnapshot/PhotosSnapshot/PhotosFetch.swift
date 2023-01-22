//
//  FetchAssets.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-21.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class PhotosFetch {
    let fetchStats: FetchStats
    let resourceManager: PHAssetResourceManager
    let fetchOptions: PHAssetResourceRequestOptions
    let dispatchGroup: DispatchGroup
    let options: CmdLineArgs
    
    init(cmdLineArgs: CmdLineArgs) {
        options = cmdLineArgs
        fetchStats = FetchStats()
        resourceManager = PHAssetResourceManager()
        dispatchGroup = DispatchGroup()
        
        fetchOptions = PHAssetResourceRequestOptions()
        fetchOptions.isNetworkAccessAllowed = !options.localOnly
        if (options.verbose && !fetchOptions.isNetworkAccessAllowed) {
            print("Excluding network assets")
        }
    }
    
    func fetchAssets(media: PHFetchResult<PHAsset>, destFolder: URL) -> FetchStats {
        for i in 0...media.count-1 {
            let resources = PHAssetResource.assetResources(for: media.object(at: i))
            for resource in findSupportedResources(resources: resources) {
                dispatchGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    self.readFile(resource: resource, parentFolder: destFolder)
                }
            }
        }
        // Wait for all the readFile() calls
        dispatchGroup.wait()
        return fetchStats
    }
    
    func readFile(resource: PHAssetResource, parentFolder: URL) {
        let filename = ResourceUtils.path(resource: resource)
        if (options.verbose) {
            print("Fetching: \(filename)")
        }
        let dest = URL(fileURLWithPath: filename, relativeTo: parentFolder)
        do {
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            // TODO: stderr
            print("Unable to create asset folder: \(dest.deletingLastPathComponent())")
            fetchStats.record(resource: resource, success: false)
            dispatchGroup.leave()
            return
        }
        
        // Do not overwrite
        if (FileManager.default.fileExists(atPath: dest.path)) {
            fetchStats.record(resource: resource, success: !options.warnExists)
            dispatchGroup.leave()
            return
        }
        
        // Fake it for dry runs
        if (options.dryRun) {
            FileManager.default.createFile(atPath: dest.path, contents: nil)
            dispatchGroup.leave()
            return
        }
        
        // Fetch to filesystem
        resourceManager.writeData(for: resource, toFile: dest, options: fetchOptions) { (error) in
            self.fetchStats.record(resource: resource, success: (error == nil))
            self.dispatchGroup.leave()
        }
    }
    
    func findSupportedResources(resources: [PHAssetResource]) -> [PHAssetResource] {
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
        let id = ResourceUtils.uuid(id: resources.first?.assetLocalIdentifier)
        
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
                // Videos are allowed a modifed still with no original still
                if (resources.first?.type != .video && modified.count > 0 && modified.first?.type == PHAssetResourceType.fullSizePhoto) {
                    // TODO: stderr
                    print("No original resource: \(ResourceUtils.uuid(id: id))")
                }
            }
            if (modified.count > 0) {
                valid.append(modified.first!)
                if (modified.count > 1) {
                    // TODO: stderr
                    print("Invalid modified resources: \(ResourceUtils.uuid(id: id))")
                }
            }
        }
        
        return valid
    }
}
