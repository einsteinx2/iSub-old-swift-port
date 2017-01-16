//
//  CachedRootSongsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedRootSongsLoader: CachedDatabaseLoader {
    var songs = [Song]()
    
    override var items: [Item] {
        return songs
    }
    
    override var associatedObject: Any? {
        return nil
    }
    
    override func loadModelsFromDatabase() -> Bool {
        songs = SongRepository.si.allSongs(isCachedTable: true)
        return true
    }
}
