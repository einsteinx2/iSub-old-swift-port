//
//  File.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Artist: Item, Equatable {
    var itemId: Int64 { return artistId }
    var itemName: String { return name }
}

final class Artist {
    let repository: ArtistRepository
    
    let artistId: Int64
    let serverId: Int64
    
    let name: String
    let coverArtId: String?
    let albumCount: Int?
    
    var albumSortOrder: AlbumSortOrder = .year
    
    var albums = [Album]()
    
    init(artistId: Int64, serverId: Int64, name: String, coverArtId: String?, albumCount: Int?, repository: ArtistRepository = ArtistRepository.si) {
        self.artistId = artistId
        self.serverId = serverId
        
        self.name = name
        self.coverArtId = coverArtId
        self.albumCount = albumCount
        
        self.repository = repository
    }
}
