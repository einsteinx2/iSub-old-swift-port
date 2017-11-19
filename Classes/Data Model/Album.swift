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
        
    var songs = [Song]()
    
    init(albumId: Int64, serverId: Int64, artistId: Int64?, genreId: Int64?, coverArtId: String?, name: String, songCount: Int?, duration: Int?, year: Int?, created: Date?, artistName: String?, repository: AlbumRepository = AlbumRepository.si) {
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
        self.artistName = artistName
        
        self.repository = repository
    }
}

// Calculated properties
extension Album {
    var artistDisplayName: String? {
        return artist?.name ?? artistName
    }
}
