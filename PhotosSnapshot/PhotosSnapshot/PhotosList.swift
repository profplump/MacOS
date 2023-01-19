//
//  FindAlbum.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-17.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class PhotosList {
    fileprivate func fetchOptions() -> PHFetchOptions {
        let fetchOptions: PHFetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = true
        if (ProcessInfo.processInfo.environment.index(forKey: "NO_HIDDEN") != nil) {
            print("Excluding hidden assets")
            fetchOptions.includeHiddenAssets = false
        }
        fetchOptions.includeAllBurstAssets = false
        fetchOptions.includeAssetSourceTypes = [PHAssetSourceType.typeUserLibrary]
        fetchOptions.wantsIncrementalChangeDetails = false
        if let value = ProcessInfo.processInfo.environment["FETCH_LIMIT"] {
            print("Limiting fetch to \(value) assets")
            fetchOptions.fetchLimit = Int(value)!
        }
        return fetchOptions;
    }
    
    func assetByLocalID(uuids: [String]) -> PHFetchResult<PHAsset> {
        let fetchOptions = fetchOptions()
        return PHAsset.fetchAssets(withLocalIdentifiers: uuids, options: fetchOptions)
    }
    
    func albumByName(albumName: String) -> PHAssetCollection! {
        let fetchOptions = fetchOptions()
        fetchOptions.predicate = NSPredicate(format: "title = %@", albumName)

        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: fetchOptions)
        
        if let _: AnyObject = collection.firstObject {
            return collection.firstObject
        }
        return nil
    }
    
    func media(mediaType: PHAssetMediaType) -> PHFetchResult<PHAsset> {
        let fetchOptions = fetchOptions()
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(with: mediaType, options: fetchOptions)
    }
    
    func photos() -> PHFetchResult<PHAsset> {
        return media(mediaType: .image)
    }
}
