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
        if let album = associatedObject as? ISMSAlbum {
            album.reloadSubmodels()
            songs = album.songs
        }
        return true
    }
}
