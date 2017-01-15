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
    
    class func item(itemId: Int, serverId: Int, repository: ItemRepository = AlbumRepository.si) -> Item? {
        return (repository as? AlbumRepository)?.album(albumId: itemId, serverId: serverId)
    }
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
    
    var artist: ISMSArtist?
    var genre: ISMSGenre?
    
    var songs: [ISMSSong]?
    
    init(albumId: Int, serverId: Int, artistId: Int?, genreId: Int?, coverArtId: String?, name: String, songCount: Int?, duration: Int?, year: Int?, created: Date?, repository: AlbumRepository = AlbumRepository.si) {
        self.albumId = albumId
        self.serverId = serverId
        self.artistId = artistId
        self.genreId = genreId
        self.coverArtId = coverArtId
        self.name = name
        self.songCount = songCount
        self.duration = duration
        self.year = year
        self.created = created
        self.repository = repository
    }
    
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
}

fileprivate let createdDateFormatter: DateFormatter = {
    let createdDateFormatter = DateFormatter()
    createdDateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssz"
    return createdDateFormatter
}()
