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
    private let fetchOptions: PHFetchOptions
    
    init() {
        fetchOptions = PHFetchOptions()
        if (ProcessInfo.processInfo.environment.index(forKey: "NO_HIDDEN") != nil) {
            print("Excluding hidden assets")
            fetchOptions.includeHiddenAssets = false
        } else {
            fetchOptions.includeHiddenAssets = true
        }
        fetchOptions.includeAllBurstAssets = false
        fetchOptions.includeAssetSourceTypes = [PHAssetSourceType.typeUserLibrary]
        fetchOptions.wantsIncrementalChangeDetails = false
        if let value = ProcessInfo.processInfo.environment["FETCH_LIMIT"] {
            print("Limiting fetch to \(value) assets")
            fetchOptions.fetchLimit = Int(value)!
        }
    }
    
    func assetByLocalID(uuids: [String]) -> PHFetchResult<PHAsset> {
        return PHAsset.fetchAssets(withLocalIdentifiers: uuids, options: fetchOptions)
    }
    
    func albumByName(albumName: String) -> PHAssetCollection! {
        let albumOptions = fetchOptions
        albumOptions.predicate = NSPredicate(format: "title = %@", albumName)

        let collection = PHAssetCollection.fetchAssetCollections(with: .album, subtype: .any, options: albumOptions)
        
        if let _: AnyObject = collection.firstObject {
            return collection.firstObject
        }
        return nil
    }
    
    func media(mediaType: PHAssetMediaType, oldestDate: Date? = nil) -> PHFetchResult<PHAsset> {
        let mediaOptions = fetchOptions
        if (oldestDate != nil) {
            let predicateDate = oldestDate! as CVarArg
            mediaOptions.predicate = NSPredicate(format: "creationDate >= %@ OR modificationDate >= %@", predicateDate, predicateDate)
        }
        mediaOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        print("Media options: \(mediaOptions)")
        return PHAsset.fetchAssets(with: mediaType, options: mediaOptions)
    }
    
    func photos() -> PHFetchResult<PHAsset> {
        return media(mediaType: .image)
    }
}
