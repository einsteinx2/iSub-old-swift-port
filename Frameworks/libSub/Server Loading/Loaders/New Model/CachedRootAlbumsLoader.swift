//
//  CachedRootAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedRootAlbumsLoader: CachedDatabaseLoader {
    var albums = [ISMSAlbum]()
    
    override var items: [ISMSItem] {
        return albums
    }
    
    override var associatedObject: Any? {
        return nil
    }
    
    override func loadModelsFromDatabase() -> Bool {
        albums = ISMSAlbum.allCachedAlbums()
        return true
    }
}
