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
    let fetchOptions: PHFetchOptions
    let options: CmdLineArgs
    
    init(cmdLineArgs: CmdLineArgs) {
        options = cmdLineArgs

        fetchOptions = PHFetchOptions()
        fetchOptions.includeHiddenAssets = !options.noHidden
        fetchOptions.includeAllBurstAssets = false
        fetchOptions.includeAssetSourceTypes = [PHAssetSourceType.typeUserLibrary]
        fetchOptions.wantsIncrementalChangeDetails = false
        fetchOptions.fetchLimit = options.fetchLimit ?? 0

        if (options.verbose) {
            if (!fetchOptions.includeHiddenAssets) {
                print("No Hidden: Excluding Hidden assets")
            }
            if (fetchOptions.fetchLimit > 0) {
                print("Fetch Limit: \(fetchOptions.fetchLimit) assets")
            }
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
    
    func media(mediaType: PHAssetMediaType, compareDate: Date? = nil) -> PHFetchResult<PHAsset> {
        let mediaOptions = fetchOptions
        if (compareDate != nil) {
            mediaOptions.predicate = NSPredicate(format: "creationDate >= %@ OR modificationDate >= %@", compareDate! as NSDate, compareDate! as NSDate)
        }
        mediaOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        return PHAsset.fetchAssets(with: mediaType, options: mediaOptions)
    }
    
    func photos() -> PHFetchResult<PHAsset> {
        return media(mediaType: .image)
    }
}
