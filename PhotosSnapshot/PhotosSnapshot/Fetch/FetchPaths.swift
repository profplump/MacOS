//
//  FetchPaths.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-23.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class FetchPaths {
    var baseFolder: URL
    var destFolder: URL
    var parentFolder: URL
    
    init(baseFolder: URL? = nil, destFolder: URL? = nil, parentFolder: URL) {
        self.baseFolder = baseFolder ?? URL(fileURLWithPath: "")
        self.destFolder = destFolder ?? URL(fileURLWithPath: "")
        self.parentFolder = parentFolder
        self.parentFolder.standardize()
    }
    
    func resourceDest(assetResource: AssetResource) -> URL {
        return URL(fileURLWithPath: assetResource.filename, relativeTo: destFolder)
    }
    func resourceTarget(assetResource: AssetResource) -> URL {
        return URL(fileURLWithPath: assetResource.filename, relativeTo: baseFolder)
    }
}
