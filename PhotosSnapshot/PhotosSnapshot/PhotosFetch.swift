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
        if (options.verbose) {
            if (!fetchOptions.isNetworkAccessAllowed) {
                print("Local Only: Skipping network assets")
            }
            if (options.dryRun) {
                print("Dry Run: Will create empty resource files")
            }
        }
    }
    
    func fetchAssets(media: PHFetchResult<PHAsset>, destFolder: URL, baseFolder: URL) -> FetchStats {
        for i in 0...media.count-1 {
            let resources = PHAssetResource.assetResources(for: media.object(at: i))
            for resource in findSupportedResources(resources: resources) {
                dispatchGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    self.readFile(resource: resource, destFolder: destFolder, baseFolder: baseFolder)
                }
            }
        }
        // Wait for all the readFile() calls
        dispatchGroup.wait()
        return fetchStats
    }
    
    func readFile(resource: PHAssetResource, destFolder: URL, baseFolder: URL) {
        let filename = ResourceUtils.path(resource: resource)
        let dest = URL(fileURLWithPath: filename, relativeTo: destFolder)
        let target =  URL(fileURLWithPath: filename, relativeTo: baseFolder)
        var targetValid: Bool = false

        // Ensure we have an asset folder
        do {
            // Is it cheaper to check for this path to exist first?
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
        } catch {
            // TODO: stderr
            print("Unable to create asset folder: \(dest.deletingLastPathComponent().path)")
            fetchStats.record(resource: resource, success: false)
            dispatchGroup.leave()
            return
        }
        
        // If we are incremental, check for a valid target in baseFolder
        if (options.incremental) {
            if (FileManager.default.fileExists(atPath: target.path)) {
                // TODO: Check that we have the right version of this file
                targetValid = true
            }
        }
        
        // Do not overwrite
        if (FileManager.default.fileExists(atPath: dest.path)) {
            fetchStats.record(resource: resource, success: !options.warnExists)
            dispatchGroup.leave()
            return
        }
        
        // Empty files for dry runs
        if (options.dryRun) {
            FileManager.default.createFile(atPath: dest.path, contents: nil)
            fetchStats.record(resource: resource, success: true)
            dispatchGroup.leave()
            return
        }
        
        // Handle all the thin-copy options, if we have a valid target
        if ((options.clone || options.hardlink || options.symlink) && targetValid) {
            var verb = String()
            if (options.clone) {
                verb = "Clon"
                do {
                    // I'm told this will clone when available, and we check for volume support
                    // But there is no direct test to tell when this copies instead of cloning
                    try FileManager.default.copyItem(at: target, to: dest)
                    fetchStats.record(resource: resource, success: true)
                } catch {
                     // TODO: stderr
                     print("Unable to create clone at \(dest.path)")
                     fetchStats.record(resource: resource, success: false)
                 }
            } else if (options.hardlink) {
                verb = "Hardlink"
                do {
                    try FileManager.default.linkItem(at: target, to: dest)
                    fetchStats.record(resource: resource, success: true)
                } catch {
                     // TODO: stderr
                     print("Unable to create hardlink at \(dest.path)")
                     fetchStats.record(resource: resource, success: false)
                 }
            } else if (options.symlink) {
                verb = "Symlink"
                do {
                    try FileManager.default.createSymbolicLink(at: dest, withDestinationURL: target)
                    fetchStats.record(resource: resource, success: true)
                } catch {
                     // TODO: stderr
                     print("Unable to create symlink at \(dest.path)")
                     fetchStats.record(resource: resource, success: false)
                 }
            }
            
            if (options.verbose) {
                print("\(verb.localizedCapitalized)ing: \(filename)")
            }
            dispatchGroup.leave()
            return
        }
        
        // Fetch to filesystem
        resourceManager.writeData(for: resource, toFile: dest, options: fetchOptions) { (error) in
            self.fetchStats.record(resource: resource, success: (error == nil))
            self.dispatchGroup.leave()
        }
        if (options.verbose) {
            print("Fetching: \(filename)")
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
