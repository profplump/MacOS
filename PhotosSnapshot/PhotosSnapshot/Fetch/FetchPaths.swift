//
//  FetchPaths.swift
//  PhotosSnapshot
//
//  Created by Zach Isbach on 2023-01-23.
//  Copyright © 2023 Zi3. All rights reserved.
//

import Foundation

class FetchPaths {
    var compareDate: Date?
    var baseFolder: URL
    var destFolder: URL
    var parentFolder: URL
    
    init(compareDate: Date? = nil, baseFolder: URL? = nil, destFolder: URL? = nil, parentFolder: URL) {
        self.compareDate = compareDate
        self.baseFolder = baseFolder ?? URL(fileURLWithPath: "")
        self.destFolder = destFolder ?? URL(fileURLWithPath: "")
        self.parentFolder = parentFolder
        self.parentFolder.standardize()
    }
}
