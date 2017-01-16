//
//  File.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Artist: Item {
    var itemId: Int64 { return artistId }
    var itemName: String { return name }
}

class Artist {
    let repository: ArtistRepository
    
    let artistId: Int64
    let serverId: Int64
    
    let name: String
    let coverArtId: String?
    let albumCount: Int?
    
    var albums = [Album]()
    
    init?(rxmlElement element: RXMLElement, serverId: Int64, repository: ArtistRepository = ArtistRepository.si) {
        guard let artistId = element.attribute(asInt64Optional: "id"), let name = element.attribute(asStringOptional: "name") else {
            return nil
        }
        
        self.artistId = artistId
        self.serverId = serverId
        self.name = name
        self.coverArtId = element.attribute(asStringOptional: "coverArtId")
        self.albumCount = element.attribute(asIntOptional: "albumCount")
        self.repository = repository
    }
    
    required init(result: FMResultSet, repository: ItemRepository = ArtistRepository.si) {
        self.artistId    = result.longLongInt(forColumnIndex: 0)
        self.serverId    = result.longLongInt(forColumnIndex: 1)
        self.name        = result.string(forColumnIndex: 2) ?? ""
        self.coverArtId  = result.string(forColumnIndex: 3)
        self.albumCount  = result.object(forColumnIndex: 4) as? Int
        self.repository  = repository as! ArtistRepository
    }
}
