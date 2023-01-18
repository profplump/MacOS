//
//  PhotosAccess.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-17.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation
import Photos

class PhotosAccess {
    private let semaphore: DispatchSemaphore

    init() {
        semaphore = DispatchSemaphore(value: 0)
    }
    
    func valid() -> Bool {
        return (PHPhotoLibrary.authorizationStatus(for: .readWrite) == PHAuthorizationStatus.authorized)
    }
    
    func wait() {
        semaphore.wait()
    }

    func auth(wait: Bool = false) {
        PHPhotoLibrary.requestAuthorization(for: .readWrite) {
            (status:PHAuthorizationStatus) in
            self.semaphore.signal()
            if (status != PHAuthorizationStatus.authorized) {
                print("Not authorized to access the photo library")
                return
            }
        }
        if (wait) {
            self.semaphore.wait()
        }
    }
}
