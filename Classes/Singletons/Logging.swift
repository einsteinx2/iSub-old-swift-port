//
//  Logging.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct Logging {
    static var logsFolder = SavedSettings.cachesPath() + "/Logs"
    
    static var latestLogFileName: String? {
        if let logFiles = try? FileManager.default.contentsOfDirectory(atPath: logsFolder) {
            var modifiedTime = 0.0
            var fileName: String?
            for file in logFiles {
                let path = Logging.logsFolder + "/" + file
                if let attributes = try? FileManager.default.attributesOfItem(atPath: path) {
                    if let modified = attributes[.modificationDate] as? Date, modified.timeIntervalSince1970 >= modifiedTime {
                        // This file is newer
                        fileName = file
                        modifiedTime = modified.timeIntervalSince1970
                    }
                }
            }
            return fileName
        }
        return nil
    }
    
    static func zipAllLogFiles() -> String? {
        let zipFileName = "iSub Logs.zip"
        let zipFilePath = SavedSettings.cachesPath() + "/" + zipFileName
        
        // Delete the old zip if exists
        try? FileManager.default.removeItem(atPath: zipFilePath)

        // Zip the logs
        let archive = ZKFileArchive(archivePath: zipFilePath)
        let result = archive?.deflateDirectory(logsFolder, relativeToPath: SavedSettings.cachesPath(), usingResourceFork: false)
        if let result = result, Int32(result) == zkSucceeded.rawValue {
            return zipFilePath
        }
        return nil
    }
}
