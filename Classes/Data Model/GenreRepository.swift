//
//  GenreRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct GenreRepository: ItemRepository {
    static let si = GenreRepository()
    fileprivate let gr = GenericItemRepository.si
    
    let table = "genres"
    let cachedTable = "genres"
    let itemIdField = "genreId"
    
    func genre(genreId: Int64) -> Genre? {
        return gr.item(repository: self, itemId: genreId)
    }
    
    func isPersisted(genre: Genre) -> Bool {
        return gr.isPersisted(repository: self, item: genre)
    }
    
    func delete(genre: Genre) -> Bool {
        return gr.delete(repository: self, item: genre)
    }
    
    func replace(genre: Genre) -> Bool {
        var success = true
        DatabaseSingleton.si.write.inDatabase { db in
            do {
                let query = "REPLACE INTO \(self.table) VALUES (?, ?)"
                try db.executeUpdate(query, genre.genreId, genre.name)
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func genre(name: String) -> Genre? {
        var genre: Genre?
        DatabaseSingleton.si.read.inDatabase { db in
            do {
                // First check if a record already exists
                let query = "SELECT * FROM \(self.table) WHERE name = ?"
                let result = try db.executeQuery(query, name)
                if result.next() {
                    genre = Genre(result: result, repository: self)
                } else {
                    //  It doesn't exist, so create the record
                    let insert = "INSERT INTO \(self.table) VALUES (?, ?)"
                    try db.executeUpdate(insert, NSNull(), name)
                    genre = Genre(genreId: db.lastInsertRowId(), name: name)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        return genre
    }
}

extension Genre: PersistedItem {
    class func item(itemId: Int64, serverId: Int64, repository: ItemRepository = GenreRepository.si) -> Item? {
        return (repository as? GenreRepository)?.genre(genreId: itemId)
    }
    
    var isPersisted: Bool {
        return repository.isPersisted(genre: self)
    }
    
    var hasCachedSubItems: Bool {
        return false
    }
    
    func replace() -> Bool {
        return repository.replace(genre: self)
    }
    
    func cache() -> Bool {
        return false
    }
    
    func delete() -> Bool {
        return repository.delete(genre: self)
    }
    
    func deleteCache() -> Bool {
        return false
    }
    
    func loadSubItems() {
        // No sub items
    }
}
