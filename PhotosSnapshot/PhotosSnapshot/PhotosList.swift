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
        fetchOptions.includeHiddenAssets = false
        fetchOptions.includeAllBurstAssets = false
        fetchOptions.includeAssetSourceTypes = [PHAssetSourceType.typeUserLibrary]
        fetchOptions.wantsIncrementalChangeDetails = false
        return fetchOptions;
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
