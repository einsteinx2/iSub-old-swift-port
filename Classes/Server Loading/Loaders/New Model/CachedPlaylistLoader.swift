//
//  CacheQueueLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 3/2/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class CachedPlaylistLoader: CachedDatabaseLoader {
    let playlistId: Int64
    
    var songs = [Song]()
    
    override var items: [Item] {
        return songs
    }
    
    override var associatedItem: Item? {
        return PlaylistRepository.si.playlist(playlistId: playlistId, serverId: serverId)
    }
    
    init(playlistId: Int64, serverId: Int64) {
        self.playlistId = playlistId
        super.init(serverId: serverId)
    }
    
    override func loadModelsFromDatabase() -> Bool {
        if let playlist = associatedItem as? Playlist {
            PlaylistRepository.si.loadSubItems(playlist: playlist)
            songs = playlist.songs
        }
        return true
    }
}
