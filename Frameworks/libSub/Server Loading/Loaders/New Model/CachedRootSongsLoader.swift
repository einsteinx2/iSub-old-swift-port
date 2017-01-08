//
//  CachedRootSongsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedRootSongsLoader: CachedDatabaseLoader {
    var songs = [ISMSSong]()
    
    override var items: [ISMSItem] {
        return songs
    }
    
    override var associatedObject: Any? {
        return nil
    }
    
    override func loadModelsFromDatabase() -> Bool {
        songs = ISMSSong.allCachedSongs()
        return true
    }
}
