//
//  CachedArtistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedArtistLoader: CachedDatabaseLoader {
    let artistId: Int
    let serverId: Int
    
    var albums = [ISMSAlbum]()
    
    override var items: [ISMSItem] {
        return albums
    }
    
    override var associatedObject: Any? {
        return ISMSArtist(artistId: artistId, serverId: serverId, loadSubmodels: false)
    }
    
    init(artistId: Int, serverId: Int) {
        self.artistId = artistId
        self.serverId = serverId
        super.init()
    }
    
    override func loadModelsFromDatabase() -> Bool {
        albums = ISMSAlbum.albums(inArtist: artistId, serverId: serverId, cachedTable: true)
        return true
    }
}
