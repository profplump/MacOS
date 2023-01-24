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
    let options: CmdLineArgs
    let fetchPaths: FetchPaths
    let fetchStats: FetchStats
    let compareDate: Date?
    let dispatchGroup: DispatchGroup
    let resourceManager: PHAssetResourceManager
    let fetchOptions: PHAssetResourceRequestOptions

    init(cmdLineArgs: CmdLineArgs, fetchPaths: FetchPaths, compareDate: Date? = nil) {
        options = cmdLineArgs
        self.fetchPaths = fetchPaths
        fetchStats = FetchStats()
        self.compareDate = compareDate
        dispatchGroup = DispatchGroup()
        resourceManager = PHAssetResourceManager()

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
    
    func fetchAssets(media: PHFetchResult<PHAsset>) -> FetchStats {
        for i in 0...media.count-1 {
            let asset = media.object(at: i)
            let resources = PHAssetResource.assetResources(for: asset)
            for resource in findSupportedResources(resources: resources) {
                let assetResource = AssetResource(asset: asset, resource: resource, compareDate: compareDate)

                // Determine if base contains a plausibly valid copy of this resource
                var baseAssetValid = false
                if (options.incremental) {
                    let target = fetchPaths.resourceTarget(assetResource: assetResource)
                    if (FileManager.default.fileExists(atPath: target.path) && !assetResource.outdated()) {
                        baseAssetValid = true
                    }
                }
                    
                dispatchGroup.enter()
                DispatchQueue.global(qos: .utility).async {
                    self.readFile(assetResource: assetResource, baseRefValid: baseAssetValid)
                }
            }
        }
        
        // Wait for all the readFile() calls
        dispatchGroup.wait()
        
        // Clean up our verify temp directory
        if (options.verify) {
            do {
                try FileManager.default.removeItem(at: fetchPaths.destFolder)
            } catch {
                print("Unable to remove verify folder: \(fetchPaths.destFolder.path)")
            }
        }
        
        // Let our overlords judge our performance
        return fetchStats
    }
    
    func readFile(assetResource: AssetResource, baseRefValid: Bool) {
        let dest = fetchPaths.resourceDest(assetResource: assetResource)
        let target = fetchPaths.resourceTarget(assetResource: assetResource)

        // Skip existing files, one way or another
        if (FileManager.default.fileExists(atPath: dest.path)) {
            if (options.verbose) {
                print("Exists: \(assetResource.filename)")
            }
            fetchStats.record(assetResource: assetResource, success: !options.warnExists)
            dispatchGroup.leave()
            return
        }
        
        // Empty files for dry runs
        if (options.dryRun) {
            do {
                try createAssetFolder(dest: dest)
                FileManager.default.createFile(atPath: dest.path, contents: nil)
                fetchStats.record(assetResource: assetResource, success: true)
            } catch {
                print("Unable to create dry run file at: \(dest.path)")
                fetchStats.record(assetResource: assetResource, success: false)
            }
            if (options.verbose) {
                print("Dry Running: \(assetResource.filename)")
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
                fetchStats.record(assetResource: assetResource, success: true)
            } catch {
                print("Unable to create thin copy at \(dest.path)")
                fetchStats.record(assetResource: assetResource, success: false)
            }
                        
            if (options.verbose) {
                print("\(verb.localizedCapitalized)ing: \(assetResource.filename)")
            }
            dispatchGroup.leave()
            return
        }
        
        // Incremental operations with a valid base copy don't need to re-fetch
        if (options.incremental && !thinCopy && baseRefValid) {
            if (options.verbose) {
                print("Base Exists: \(assetResource.filename)")
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
        resourceManager.writeData(for: assetResource.resource, toFile: dest, options: fetchOptions) { (error) in
            if (error != nil) {
                print("Resource fetch error: \(dest.path)")
                self.fetchStats.record(assetResource: assetResource, success: false)
                self.dispatchGroup.leave()
                return
            }

            // Success, unless we still need to verify
            if (self.options.verify) {
                if (assetResource.outdated()) {
                    if (self.options.verbose) {
                        print("Not Verifying: \(assetResource.filename)")
                    }
                } else {
                    let verified = self.verify(assetResource: assetResource)
                    self.fetchStats.record(assetResource: assetResource, success: verified)
                }
            } else {
                self.fetchStats.record(assetResource: assetResource, success: true)
            }
            self.dispatchGroup.leave()
        }
        if (options.verbose) {
            print("Fetching: \(assetResource.filename)")
        }
    }
    
    func verify(assetResource: AssetResource) -> Bool {
        let dest = fetchPaths.resourceDest(assetResource: assetResource)
        let target = fetchPaths.resourceTarget(assetResource: assetResource)
        var verified = false

        if (FileManager.default.contentsEqual(atPath: dest.path, andPath: target.path)) {
            verified = true
        } else {
            verified = false
            print("File content does not match: \(assetResource.filename)")
        }
        if (options.verbose) {
            print("Verifying: \(assetResource.filename)")
        }
        do {
            try FileManager.default.removeItem(at: dest)
        } catch {
            print("Unable to remove verify file: \(dest.path)")
        }
        return verified
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
        let id = AssetResource.uuid(id: resources.first?.assetLocalIdentifier)
        
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
                    print("No original resource: \(id)")
                }
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
