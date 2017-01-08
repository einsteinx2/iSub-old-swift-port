//
//  CachedAlbumLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedAlbumLoader: CachedDatabaseLoader {
    let albumId: Int
    let serverId: Int
    
    var songs = [ISMSSong]()
    var songsDuration = 0.0
    
    override var items: [ISMSItem] {
        return songs
    }
    
    override var associatedObject: Any? {
        return ISMSAlbum(albumId: albumId, serverId: serverId, loadSubmodels: false)
    }
    
    init(albumId: Int, serverId: Int) {
        self.albumId = albumId
        self.serverId = serverId
        super.init()
    }
    
    override func loadModelsFromDatabase() -> Bool {
        songs = ISMSSong.songs(inAlbum: albumId, serverId: serverId, cachedTable: true)
        songsDuration = songs.reduce(0.0) { totalDuration, song -> Double in
            if let duration = song.duration as? Double {
                return totalDuration + duration
            }
            return totalDuration
        }
        return true
    }
}
