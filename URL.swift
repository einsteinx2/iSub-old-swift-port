//
//  URL.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension URL {
    var isExcludedFromBackup: Bool {
        get {
            let resourceValues = try? self.resourceValues(forKeys: Set([URLResourceKey.isExcludedFromBackupKey]))
            if let isExcludedFromBackup = resourceValues?.isExcludedFromBackup {
                return isExcludedFromBackup
            }
            return false
        } set {
            // This URL must point to a file
            guard FileManager.default.fileExists(atPath: self.path) else {
                return
            }
            
            var resourceValues = URLResourceValues()
            resourceValues.isExcludedFromBackup = newValue
            try? self.setResourceValues(resourceValues)
        }
    }
}
