//
//  Album.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Album: Item {
    var itemId: Int64 { return albumId }
    var itemName: String { return name }
}

class Album {
    let repository: AlbumRepository
    
    let albumId: Int64
    let serverId: Int64
    
    let artistId: Int64?
    let genreId: Int64?
    let coverArtId: String?
    
    let name: String
    let songCount: Int?
    let duration: Int?
    let year: Int?
    
    let created: Date?
    
    var artist: Artist?
    var genre: Genre?
    
    var songs = [Song]()
    
    init?(rxmlElement element: RXMLElement, serverId: Int64, repository: AlbumRepository = AlbumRepository.si) {
        guard let albumId = element.attribute(asInt64Optional: "id"), let name = element.attribute(asStringOptional: "name") else {
            return nil
        }
        
        self.repository = repository
        
        self.albumId = albumId
        self.serverId = serverId
        self.artistId = element.attribute(asInt64Optional: "artistId")
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
            genre = GenreRepository.si.genre(name: genreString)
            self.genreId = genre!.genreId
        } else {
            self.genreId = nil
        }
    }
    
    required init(result: FMResultSet, repository: ItemRepository = AlbumRepository.si) {
        self.albumId     = result.longLongInt(forColumnIndex: 0)
        self.serverId    = result.longLongInt(forColumnIndex: 1)
        self.artistId    = result.object(forColumnIndex: 2) as? Int64
        self.genreId     = result.object(forColumnIndex: 3) as? Int64
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
