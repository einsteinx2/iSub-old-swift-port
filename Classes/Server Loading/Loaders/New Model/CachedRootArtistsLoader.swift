//
//  CachedRootArtistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class CachedRootArtistsLoader: CachedDatabaseLoader {
    var artists = [Artist]()
    
    override var items: [Item] {
        return artists
    }
    
    override var associatedItem: Item? {
        return nil
    }
    
    @discardableResult override func loadModelsFromDatabase() -> Bool {
        artists = ArtistRepository.si.allArtists(isCachedTable: true)
        return true
    }
}
