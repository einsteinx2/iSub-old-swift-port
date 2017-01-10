//
//  CachedRootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedRootArtistsLoader: CachedDatabaseLoader {
    var artists = [ISMSArtist]()
    
    override var items: [ISMSItem] {
        return artists
    }
    
    override var associatedObject: Any? {
        return nil
    }
    
    override func loadModelsFromDatabase() -> Bool {
        artists = ISMSArtist.allCachedArtists()
        return true
    }
}
