//
//  ArtistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class ArtistLoader: ApiLoader, ItemLoader {
    let artistId: Int
    
    var albums = [ISMSAlbum]()
    
    var items: [ISMSItem] {
        return albums
    }
    
    init(artistId: Int) {
        self.artistId = artistId
        super.init()
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getArtist, parameters: ["id": artistId])
    }
    
    override func processResponse(root: RXMLElement) {
        var albumsTemp = [ISMSAlbum]()
        
        let serverId = SavedSettings.si().currentServerId
        root.iterate("artist.album") { album in
            let anAlbum = ISMSAlbum(rxmlElement: album, serverId: serverId)
            albumsTemp.append(anAlbum)
        }
        albums = albumsTemp
        
        // Persist associated object model if needed
        if !ISMSArtist.isPersisted(NSNumber(value: artistId), serverId: NSNumber(value: serverId)) {
            if let element = root.child("artist") {
                let artist = ISMSArtist(rxmlElement: element, serverId: serverId)
                artist.replace()
            }
        }
        
        self.persistModels()
    }
    
    func persistModels() {
        // Save the new albums
        albums.forEach({$0.replace()})
        
        // Add to cache table if needed
        if let artist = associatedObject as? ISMSArtist, artist.hasCachedSongs() {
            artist.cacheModel()
        }
    }
    
    func loadModelsFromDatabase() -> Bool {
        if let artist = associatedObject as? ISMSArtist {
            artist.reloadSubmodels()
            albums = artist.albums
            return albums.count > 0
        }
        return false
    }
    
    var associatedObject: Any? {
        return ISMSArtist(artistId: artistId, serverId: SavedSettings.si().currentServerId, loadSubmodels: false)
    }
}
