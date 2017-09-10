//
//  KSEventStorage.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/19.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

let documentDirectory: String = {
    NSSearchPathForDirectoriesInDomains(.DocumentDirectory, .UserDomainMask, true)[0]
}()

func documentFile(filename: String) -> String {
    return documentDirectory + "/" + filename
}

public class KSEventStorage {
    
    static let root: String = documentFile("Events")
    
    struct Config {
        /**
            Maximum cache size in disk.
         */
        static let diskCacheSize = 50 * 1024 * 1024;    // 50 MB
    }
    
    let eventId: String
    
    required public init(eventId: String) {
        self.eventId = eventId
    }
    
    // MARK: - Storage Paths
    
    public func folderPath() -> String {
        return (KSEventStorage.root as NSString).stringByAppendingPathComponent(eventId)
    }
    
    public func playlistPath() -> String {
        return (folderPath() as NSString).stringByAppendingPathComponent("playlist.m3u8")
    }
    
    public func tsPath(filename: String) -> String {
        return (folderPath() as NSString).stringByAppendingPathComponent(filename)
    }
    
    private func assureFolder() -> Bool {
        let fm = NSFileManager()
        let folder = folderPath()
        if !fm.fileExistsAtPath(folder) {
            do {
                try fm.createDirectoryAtPath(folder, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("Create folder for event \(eventId) failed.")
                return false
            }
        }
        return true
    }
    
    private func removeFile(filePath: String) -> Bool {
        let fm = NSFileManager()
        if fm.fileExistsAtPath(filePath) {
            do {
                try fm.removeItemAtPath(filePath)
            } catch {
                print("Remove file failed - \(filePath)")
                return false
            }
        }
        return true
    }
    
    // MARK: - Playlist
    
    public func loadPlaylist() -> HLSPlaylist? {
        if let data = NSData(contentsOfFile: playlistPath()) {
            return HLSPlaylist(data: data)
        } else {
            return nil
        }
    }
    
    public func savePlaylist(text: String) -> Bool {
        // assure folder exists
        if !assureFolder() { return false }
        
        let filePath = playlistPath()
        
        // remove old file
        if !removeFile(filePath) { return false }

        // save file
        do {
            try text.writeToFile(filePath, atomically: true, encoding: NSUTF8StringEncoding)
            return true
        } catch {
            print("Save playlist for event \(eventId) failed.")
            return false
        }
    }
    
    // MARK: - TS
    
    public func tsFileExists(filename: String) -> Bool {
        return NSFileManager().fileExistsAtPath(tsPath(filename))
    }
    
    public func loadTS(filename: String) -> NSData? {
        do {
            return try NSData.init(contentsOfFile: tsPath(filename), options: NSDataReadingOptions.UncachedRead)
        } catch {
            return nil
        }
    }
    
    public func saveTS(data: NSData, filename: String) -> Bool {
        // assure folder exists
        if !assureFolder() { return false }
        
        let filePath = tsPath(filename)
        
        // remove old file
        if !removeFile(filePath) { return false }
        
        // save file
        return data.writeToFile(filePath, atomically: true)
    }
    
    public func deleteFiles() -> Bool {
        do {
            try NSFileManager.defaultManager().removeItemAtPath(folderPath())
            return true
        } catch {
            print("Delete event \(eventId) failed.")
            return false
        }
    }
}
