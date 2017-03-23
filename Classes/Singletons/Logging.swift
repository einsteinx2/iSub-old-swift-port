//
//  Logging.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import XCGLogger

let log = XCGLogger(identifier: "advancedLogger", includeDefaultDestinations: false)

func printError(_ error: Any, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = NSURL(fileURLWithPath: file).deletingPathExtension?.lastPathComponent
    let functionName = function.components(separatedBy: "(").first
    
    if let fileName = fileName, let functionName = functionName {
        log.error("[\(fileName):\(line) \(functionName)] \(error)")
    } else {
        log.error("[\(file):\(line) \(function)] \(error)")
    }
}

struct Logging {
    static var logsFolder = cachesPath + "/Logs"
    
    fileprivate static let logCountKey = "logCount"
    fileprivate static var logCount: Int {
        get {
            return UserDefaults.standard.integer(forKey: logCountKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: logCountKey)
        }
    }
    
    fileprivate static var logFileName: String = {
        let fileName = "log\(logCount).txt"
        logCount += 1
        return fileName
    }()
    
    static var logFilePath: String {
        return logsFolder + "/" + logFileName
    }
    
    static func zipAllLogFiles() -> String? {
        let zipFileName = "iSub Logs.zip"
        let zipFilePath = cachesPath + "/" + zipFileName
        
        // Delete the old zip if exists
        try? FileManager.default.removeItem(atPath: zipFilePath)

        // Zip the logs
        let archive = ZKFileArchive(archivePath: zipFilePath)
        let result = archive?.deflateDirectory(logsFolder, relativeToPath: cachesPath, usingResourceFork: false)
        if let result = result, Int32(result) == zkSucceeded.rawValue {
            return zipFilePath
        }
        return nil
    }
    
    static func setupLogger() {
        if !FileManager.default.fileExists(atPath: logsFolder) {
            try? FileManager.default.createDirectory(atPath: logsFolder, withIntermediateDirectories: true, attributes: nil)
        }
        
        // Create a destination for the system console log (via NSLog)
        let systemDestination = AppleSystemLogDestination(identifier: "advancedLogger.systemDestination")
        
        // Optionally set some configuration options
        systemDestination.outputLevel = .debug
        systemDestination.showLogIdentifier = false
        systemDestination.showFunctionName = true
        systemDestination.showThreadName = true
        systemDestination.showLevel = true
        systemDestination.showFileName = true
        systemDestination.showLineNumber = true
        systemDestination.showDate = true
        
        // Add the destination to the logger
        log.add(destination: systemDestination)
        
        // Create a file log destination
        let fileDestination = FileDestination(writeToFile: logFilePath, identifier: "advancedLogger.fileDestination")
        
        // Optionally set some configuration options
        fileDestination.outputLevel = .debug
        fileDestination.showLogIdentifier = false
        fileDestination.showFunctionName = true
        fileDestination.showThreadName = true
        fileDestination.showLevel = true
        fileDestination.showFileName = true
        fileDestination.showLineNumber = true
        fileDestination.showDate = true
        
        // Process this destination in the background
        fileDestination.logQueue = XCGLogger.logQueue
        
        // Add the destination to the logger
        log.add(destination: fileDestination)
        
        // Add basic app info, version info etc, to the start of the logs
        log.logAppDetails()
    }
}
