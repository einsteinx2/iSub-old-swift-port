//
//  Genre.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Genre: Item, Equatable {
    var itemId: Int64 { return genreId }
    var itemName: String { return name }
    var serverId: Int64 { return -1 }
}

final class Genre {
    let repository: GenreRepository
    
    let genreId: Int64
    let name: String
    
    init(genreId: Int64, name: String, repository: GenreRepository = GenreRepository.si) {
        self.genreId = genreId
        self.name = name
        self.repository = repository
    }
    
    required init(result: FMResultSet, repository: ItemRepository) {
        self.genreId    = result.longLongInt(forColumnIndex: 0)
        self.name       = result.string(forColumnIndex: 1) ?? ""
        self.repository = repository as! GenreRepository
    }
}
