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
    
    func fetchAssets(media: PHFetchResult<PHAsset>, fetchPaths: FetchPaths) -> FetchStats {
        for i in 0...media.count-1 {
            let asset = media.object(at: i)
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in findSupportedResources(resources: resources) {
                // Determine if base contains a plausibly valid copy of this resource
                var baseAssetValid = false
                if (options.incremental) {
                    var invalid = false
                    let target = URL(fileURLWithPath: ResourceUtils.path(resource: resource), relativeTo: fetchPaths.baseFolder)
                    // Exists
                    if (!FileManager.default.fileExists(atPath: target.path)) {
                        invalid = true
                    }
                    // Is recent enough
                    if (max(asset.creationDate ?? Date.distantFuture, asset.modificationDate ?? Date.distantFuture) >= fetchPaths.compareDate ??  Date.now) {
                        invalid = true
                    }
                    baseAssetValid = !invalid
                }
                    
                dispatchGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    self.readFile(resource: resource, fetchPaths: fetchPaths, baseRefValid: baseAssetValid)
                }
            }
        }
        // Wait for all the readFile() calls
        dispatchGroup.wait()
        return fetchStats
    }
    
    func readFile(resource: PHAssetResource, fetchPaths: FetchPaths, baseRefValid: Bool) {
        let filename = ResourceUtils.path(resource: resource)
        let dest = URL(fileURLWithPath: filename, relativeTo: fetchPaths.destFolder)
        let target = URL(fileURLWithPath: filename, relativeTo: fetchPaths.baseFolder)

        // Do not overwrite
        if (FileManager.default.fileExists(atPath: dest.path)) {
            fetchStats.record(resource: resource, success: !options.warnExists)
            dispatchGroup.leave()
            return
        }
        
        // Empty files for dry runs
        if (options.dryRun) {
            do {
                try createAssetFolder(dest: dest)
                FileManager.default.createFile(atPath: dest.path, contents: nil)
                fetchStats.record(resource: resource, success: true)
            } catch {
                print("Unable to create dry run file at: \(dest.path)")
                fetchStats.record(resource: resource, success: false)
            }
            if (options.verbose) {
                print("Dry Running: \(filename)")
            }
            dispatchGroup.leave()
            return
        }
        
        // Handle all the thin-copy options, if we have a valid baseReference
        let thinCopy = (options.incremental && (options.clone || options.hardlink || options.symlink))
        if (baseRefValid && thinCopy) {
            var verb = String()
            do {
                try createAssetFolder(dest: dest)
                if (options.clone) {
                    verb = "Clon"
                    try FileManager.default.copyItem(at: target, to: dest)
                } else if (options.hardlink) {
                    verb = "Hardlink"
                    try FileManager.default.linkItem(at: target, to: dest)
                } else if (options.symlink) {
                    verb = "Symlink"
                    try FileManager.default.createSymbolicLink(at: dest, withDestinationURL: target)
                }
                fetchStats.record(resource: resource, success: true)
            } catch {
                print("Unable to create thin copy at \(dest.path)")
                fetchStats.record(resource: resource, success: false)
            }
                        
            if (options.verbose) {
                print("\(verb.localizedCapitalized)ing: \(filename)")
            }
            dispatchGroup.leave()
            return
        }
        
        // Incremental operations with a valid base copy don't need to re-fetch
        if (options.incremental && !thinCopy && baseRefValid) {
            if (options.verbose) {
                print("Skipping: \(filename)")
            }
            dispatchGroup.leave()
            return
        }
        
        // Fetch to filesystem if we are still around
        do {
            try createAssetFolder(dest: dest)
        } catch {
            print("Unable to create asset folder: \(dest.path)")
            dispatchGroup.leave()
            return
        }
        resourceManager.writeData(for: resource, toFile: dest, options: fetchOptions) { (error) in
            self.fetchStats.record(resource: resource, success: (error == nil))
            self.dispatchGroup.leave()
        }
        if (options.verbose) {
            print("Fetching: \(filename)")
        }
    }
    
    func createAssetFolder(dest: URL) throws {
        var isDir: ObjCBool = true
        if (!FileManager.default.fileExists(atPath: dest.deletingLastPathComponent().path, isDirectory: &isDir)) {
            try FileManager.default.createDirectory(at: dest.deletingLastPathComponent(), withIntermediateDirectories: true)
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
                    print("No original resource: \(ResourceUtils.uuid(id: id))")
                }
            }
            if (modified.count > 0) {
                valid.append(modified.first!)
                if (modified.count > 1) {
                    print("Invalid modified resources: \(ResourceUtils.uuid(id: id))")
                }
            }
        }
        
        return valid
    }
}
