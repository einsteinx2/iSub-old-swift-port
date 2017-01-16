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
    
    let folderId: Int64
    let serverId: Int64
    
    var folders = [Folder]()
    var songs = [Song]()
    var songsDuration = 0
    
    override var items: [Item] {
        return folders as [Item] + songs as [Item]
    }
    
    override var associatedObject: Any? {
        return FolderRepository.si.folder(folderId: folderId, serverId: serverId)
    }
    
    init(folderId: Int64, serverId: Int64) {
        self.folderId = folderId
        self.serverId = serverId
        super.init()
    }
    
    override func loadModelsFromDatabase() -> Bool {
        folders = FolderRepository.si.folders(parentFolderId: folderId, serverId: serverId, isCachedTable: true)
        songs = SongRepository.si.songs(folderId: folderId, serverId: serverId, isCachedTable: true)
        songsDuration = songs.reduce(0) { totalDuration, song -> Int in
            if let duration = song.duration {
                return totalDuration + duration
            }
            return totalDuration
        }
        return true
    }
}
