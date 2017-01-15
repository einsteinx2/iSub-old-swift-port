//
//  Genre.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Genre: Item {
    var itemId: Int { return genreId }
    var itemName: String { return name }
    var serverId: Int { return -1 }
    
    class func item(itemId: Int, serverId: Int, repository: ItemRepository = GenreRepository.si) -> Item? {
        return (repository as? GenreRepository)?.genre(genreId: itemId)
    }
}

class Genre {
    let repository: GenreRepository
    
    let genreId: Int
    let name: String
    
    init(genreId: Int, name: String, repository: GenreRepository = GenreRepository.si) {
        self.genreId = genreId
        self.name = name
        self.repository = repository
    }
    
    required init(result: FMResultSet, repository: ItemRepository) {
        self.genreId    = result.long(forColumnIndex: 0)
        self.name       = result.string(forColumnIndex: 1) ?? ""
        self.repository = repository as! GenreRepository
    }
}
