//
//  ArtistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class ArtistLoader: ApiLoader, ItemLoader {
    let artistId: Int64
    
    var albums = [Album]()
    
    var items: [Item] {
        return albums
    }
    
    init(artistId: Int64) {
        self.artistId = artistId
        super.init()
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getArtist, parameters: ["id": artistId])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var albumsTemp = [Album]()
        
        let serverId = SavedSettings.si.currentServerId
        root.iterate("artist.album") { album in
            if let anAlbum = Album(rxmlElement: album, serverId: serverId) {
                albumsTemp.append(anAlbum)
            }
        }
        albums = albumsTemp
        
        // Persist associated object model if needed
        if !ArtistRepository.si.isPersisted(artistId: artistId, serverId: serverId) {
            if let element = root.child("artist"), let artist = Artist(rxmlElement: element, serverId: serverId) {
                _ = artist.replace()
            }
        }
        
        persistModels()
        
        return true
    }
    
    func persistModels() {
        // Save the new albums
        albums.forEach({_ = $0.replace()})
        
        // Add to cache table if needed
        if let artist = associatedObject as? Artist, artist.hasCachedSubItems {
            _ = artist.cache()
        }
    }
    
    func loadModelsFromDatabase() -> Bool {
        if let artist = associatedObject as? Artist {
            artist.loadSubItems()
            albums = artist.albums
            return albums.count > 0
        }
        return false
    }
    
    var associatedObject: Any? {
        let serverId = SavedSettings.si.currentServerId
        return ArtistRepository.si.artist(artistId: artistId, serverId: serverId)
    }
}
