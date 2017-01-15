//
//  Album.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Album: Item {
    var itemId: Int { return albumId }
    var itemName: String { return name }
}

class Album {
    let repository: AlbumRepository
    
    let albumId: Int
    let serverId: Int
    
    let artistId: Int?
    let genreId: Int?
    let coverArtId: String?
    
    let name: String
    let songCount: Int?
    let duration: Int?
    let year: Int?
    
    let created: Date?
    
    var artist: Artist?
    var genre: Genre?
    
    var songs = [Song]()
    
    init?(rxmlElement element: RXMLElement, serverId: Int, repository: AlbumRepository = AlbumRepository.si) {
        guard let albumId = element.attribute(asIntOptional: "id"), let name = element.attribute(asStringOptional: "name") else {
            return nil
        }
        
        self.repository = repository
        
        self.albumId = albumId
        self.serverId = serverId
        self.artistId = element.attribute(asIntOptional: "artistId")
        self.coverArtId = element.attribute("coverArt")?.clean
        
        self.name = name
        self.songCount = element.attribute(asIntOptional: "songCount")
        self.duration = element.attribute(asIntOptional: "duration")
        self.year = element.attribute(asIntOptional: "year")
        
        if let createdString = element.attribute(asStringOptional: "created") {
            self.created = createdDateFormatter.date(from: createdString)
        } else {
            self.created = nil
        }
        
        if let genreString = element.attribute(asStringOptional: "genre") {
            let genre = ISMSGenre(name: genreString)
            self.genreId = genre.genreId as? Int
        } else {
            self.genreId = nil
        }
    }
    
    required init(result: FMResultSet, repository: ItemRepository = AlbumRepository.si) {
        self.albumId     = result.long(forColumnIndex: 0)
        self.serverId    = result.long(forColumnIndex: 1)
        self.artistId    = result.object(forColumnIndex: 2) as? Int
        self.genreId     = result.object(forColumnIndex: 3) as? Int
        self.coverArtId  = result.string(forColumnIndex: 4)
        self.name        = result.string(forColumnIndex: 5) ?? ""
        self.songCount   = result.object(forColumnIndex: 6) as? Int
        self.duration    = result.object(forColumnIndex: 7) as? Int
        self.year        = result.object(forColumnIndex: 8) as? Int
        self.created     = result.date(forColumnIndex: 9)
        self.repository  = repository as! AlbumRepository
    }
}

fileprivate let createdDateFormatter: DateFormatter = {
    let createdDateFormatter = DateFormatter()
    createdDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
    return createdDateFormatter
}()
