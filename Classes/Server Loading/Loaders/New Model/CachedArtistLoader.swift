//
//  CachedArtistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class CachedArtistLoader: CachedDatabaseLoader {
    let artistId: Int64
    let serverId: Int64
    
    var albums = [Album]()
    
    override var items: [Item] {
        return albums
    }
    
    override var associatedItem: Item? {
        return ArtistRepository.si.artist(artistId: artistId, serverId: serverId)
    }
    
    init(artistId: Int64, serverId: Int64) {
        self.artistId = artistId
        self.serverId = serverId
        super.init()
    }
    
    override func loadModelsFromDatabase() -> Bool {
        albums = AlbumRepository.si.albums(artistId: artistId, serverId: serverId, isCachedTable: true)
        return true
    }
}
