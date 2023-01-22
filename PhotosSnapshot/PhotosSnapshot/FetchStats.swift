//
//  FetchStats.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-21.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class FetchStats {
    var assetSuccess: Set<String> = Set<String>()
    var assetError: Set<String> = Set<String>()
    var resourceSuccess: Set<String> = Set<String>()
    var resourceError: Set<String> = Set<String>()
    let fetchStatsSemaphore: DispatchSemaphore
    
    init() {
        fetchStatsSemaphore = DispatchSemaphore(value: 1)
    }
    
    func record(resource: PHAssetResource, success: Bool) {
        let uuid = ResourceUtils.uuid(id: resource.assetLocalIdentifier)
        let path = ResourceUtils.path(resource: resource)

        fetchStatsSemaphore.wait()
        if (success) {
            self.resourceSuccess.insert(path)
            self.assetSuccess.insert(uuid)
        } else {
            self.resourceError.insert(path)
            self.assetError.insert(uuid)
            // TODO: stderr
            print("Resource fetch error: \(path)")
        }
        fetchStatsSemaphore.signal()
    }
}
