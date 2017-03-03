//
//  CachedRootAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class CachedRootAlbumsLoader: CachedDatabaseLoader {
    var albums = [Album]()
    
    override var items: [Item] {
        return albums
    }
    
    override var associatedItem: Item? {
        return nil
    }
    
    override func loadModelsFromDatabase() -> Bool {
        albums = AlbumRepository.si.allAlbums(isCachedTable: true)
        return true
    }
}
