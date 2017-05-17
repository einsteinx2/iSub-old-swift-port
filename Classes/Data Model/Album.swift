//
//  Album.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Album: Item, Equatable {
    var itemId: Int64 { return albumId }
    var itemName: String { return name }
}

final class Album {
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
    
    let artistName: String?
    
    var songSortOrder: SongSortOrder = .track
    
    var artist: Artist?
    var genre: Genre?
        
    var artistDisplayName: String? {
        return artist?.name ?? artistName
    }
    
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
        
        self.artistName = element.attribute(asStringOptional: "artist")
        
        if let genreString = element.attribute(asStringOptional: "genre") {
            genre = GenreRepository.si.genre(name: genreString)
            // TODO: Figure out why this ever returns a nil genre, it should be impossible without a database error
            // which should also be impossible
            self.genreId = genre?.genreId
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
        self.artistName  = result.string(forColumnIndex: 10)
        self.songSortOrder  = SongSortOrder(rawValue: result.long(forColumnIndex: 11)) ?? .track
        self.repository  = repository as! AlbumRepository
    }
}

fileprivate let createdDateFormatter: DateFormatter = {
    let createdDateFormatter = DateFormatter()
    createdDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
    return createdDateFormatter
}()
