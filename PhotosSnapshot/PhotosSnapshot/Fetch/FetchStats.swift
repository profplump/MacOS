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
    
    func record(assetResource: AssetResource, success: Bool) {
        fetchStatsSemaphore.wait()
        if (success) {
            self.resourceSuccess.insert(assetResource.filename)
            self.assetSuccess.insert(assetResource.uuid)
        } else {
            self.resourceError.insert(assetResource.filename)
            self.assetError.insert(assetResource.uuid)
        }
        fetchStatsSemaphore.signal()
    }
}
