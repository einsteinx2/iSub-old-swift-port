//
//  File.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Artist: Item {
    var itemId: Int { return artistId }
    var itemName: String { return name }
    
    class func item(itemId: Int, serverId: Int, repository: ItemRepository = ArtistRepository.si) -> Item? {
        return (repository as? ArtistRepository)?.artist(artistId: itemId, serverId: serverId)
    }
}

class Artist {
    let repository: ArtistRepository
    
    let artistId: Int
    let serverId: Int
    
    let name: String
    let coverArtId: String?
    let albumCount: Int?
    
    var albums: [Album]?
    
    init(artistId: Int, serverId: Int, name: String, coverArtId: String?, albumCount: Int?, repository: ArtistRepository = ArtistRepository.si) {
        self.artistId = artistId
        self.serverId = serverId
        self.name = name
        self.coverArtId = coverArtId
        self.albumCount = albumCount
        self.repository = repository
    }
    
    init?(rxmlElement element: RXMLElement, serverId: Int, repository: ArtistRepository = ArtistRepository.si) {
        guard let artistId = element.attribute(asIntOptional: "id"), let name = element.attribute(asStringOptional: "name") else {
            return nil
        }
        
        self.artistId = artistId
        self.serverId = serverId
        self.name = name
        self.coverArtId = element.attribute(asStringOptional: "coverArtId")
        self.albumCount = element.attribute(asIntOptional: "albumCount")
        self.repository = repository
    }
}
