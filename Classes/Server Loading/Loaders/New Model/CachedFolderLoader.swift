//
//  CachedFolderLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedFolderLoader: CachedDatabaseLoader {
    fileprivate static var operationQueues = [OperationQueue]()
    
    let folderId: Int
    let serverId: Int
    
    var folders = [ISMSFolder]()
    var songs = [ISMSSong]()
    var songsDuration = 0.0
    
    override var items: [ISMSItem] {
        return folders as [ISMSItem] + songs as [ISMSItem]
    }
    
    override var associatedObject: Any? {
        return ISMSFolder(folderId: folderId, serverId: serverId, loadSubmodels: false)
    }
    
    init(folderId: Int, serverId: Int) {
        self.folderId = folderId
        self.serverId = serverId
        super.init()
    }
    
    override func loadModelsFromDatabase() -> Bool {
        folders = ISMSFolder.folders(inFolder: folderId, serverId: serverId, cachedTable: true)
        songs = ISMSSong.songs(inFolder: folderId, serverId: serverId, cachedTable: true)
        songsDuration = songs.reduce(0.0) { totalDuration, song -> Double in
            if let duration = song.duration as? Double {
                return totalDuration + duration
            }
            return totalDuration
        }
        return true
    }
}
