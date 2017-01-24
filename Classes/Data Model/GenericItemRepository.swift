//
//  GenericItemRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

protocol ItemRepository {
    var table: String { get }
    var cachedTable: String { get }
    var itemIdField: String { get }
}

func tableName(repository: ItemRepository, isCachedTable: Bool = false) -> String {
    return isCachedTable ? repository.cachedTable : repository.table
}

class GenericItemRepository {
    static var si = GenericItemRepository()
    
    func item<T: PersistedItem>(repository: ItemRepository, itemId: Int64, serverId: Int64? = nil, loadSubItems: Bool = false) -> T? {
        func runQuery(db: FMDatabase, table: String) -> T? {
            var item: T? = nil
            var query = "SELECT * FROM \(table) WHERE \(repository.itemIdField) = ?"
            do {
                let result: FMResultSet
                if let serverId = serverId {
                    query += " AND serverId = ?"
                    result = try db.executeQuery(query, itemId, serverId)
                } else {
                    result = try db.executeQuery(query, itemId)
                }
                if result.next() {
                    item = T(result: result, repository: repository)
                }
                result.close()
            } catch {
                printError(error)
            }
            return item
        }
        
        var item: T? = nil
        Database.si.read.inDatabase { db in
            item = runQuery(db: db, table: repository.table)
            if item == nil {
                item = runQuery(db: db, table: repository.cachedTable)
            }
        }
        
        if loadSubItems, let item = item {
            item.loadSubItems()
        }
        
        return item
    }
    
    func allItems<T: PersistedItem>(repository: ItemRepository, serverId: Int64? = nil, isCachedTable: Bool = false) -> [T] {
        let ignoredArticles = Database.si.ignoredArticles
        var items = [T]()
        var itemsNumbers = [T]()
        Database.si.read.inDatabase { db in
            let table = tableName(repository: repository, isCachedTable: isCachedTable)
            var query = "SELECT * FROM \(table)"
            do {
                let result: FMResultSet
                if let serverId = serverId {
                    query += " WHERE serverId = ?"
                    result = try db.executeQuery(query, serverId)
                } else {
                    result = try db.executeQuery(query)
                }
                
                while result.next() {
                    let item = T(result: result, repository: repository)
                    let name = Database.si.name(item.itemName, ignoringArticles: ignoredArticles)
                    if let firstScalar = name.unicodeScalars.first {
                        if CharacterSet.letters.contains(firstScalar) {
                            items.append(item)
                        } else {
                            itemsNumbers.append(item)
                        }
                    }
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        items = subsonicSorted(items: items, ignoredArticles: ignoredArticles)
        items.append(contentsOf: itemsNumbers)
        
        for item in items {
            item.loadSubItems()
        }
        
        return items
    }
    
    func deleteAllItems(repository: ItemRepository, serverId: Int64?) -> Bool {
        var success = true
        Database.si.write.inDatabase { db in
            do {
                if let serverId = serverId {
                    let query = "DELETE FROM \(repository.table) WHERE serverId = ?"
                    try db.executeUpdate(query, serverId)
                } else {
                    let query = "DELETE FROM \(repository.table)"
                    try db.executeUpdate(query)
                }
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func isPersisted<T: PersistedItem>(repository: ItemRepository, item: T, isCachedTable: Bool = false) -> Bool {
        return isPersisted(repository: repository, itemId: item.itemId, serverId: item.serverId)
    }
    
    func isPersisted(repository: ItemRepository, itemId: Int64, serverId: Int64, isCachedTable: Bool = false) -> Bool {
        let table = tableName(repository: repository, isCachedTable: isCachedTable)
        let query = "SELECT COUNT(*) FROM \(table) WHERE \(repository.itemIdField) = ? AND serverId = ?"
        return Database.si.read.boolForQuery(query, itemId, serverId)
    }
    
    func hasCachedSubItems<T: PersistedItem>(repository: ItemRepository, item: T) -> Bool {
        let query = "SELECT COUNT(*) FROM cachedSongs WHERE \(repository.itemIdField) = ? AND serverId = ?"
        return Database.si.read.boolForQuery(query, item.itemId, item.serverId)
    }
    
    func delete<T: PersistedItem>(repository: ItemRepository, item: T, isCachedTable: Bool = false) -> Bool {
        var success = true
        Database.si.write.inDatabase { db in
            do {
                let table = tableName(repository: repository, isCachedTable: isCachedTable)
                let query = "DELETE FROM \(table) WHERE \(repository.itemIdField) = ? AND serverId = ?"
                try db.executeUpdate(query, item.itemId, item.serverId)
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
}

func subsonicSorted<T: Item>(items: [T], ignoredArticles: [String]) -> [T] {
    return items.sorted {
        var name1 = Database.si.name($0.itemName.lowercased(), ignoringArticles: ignoredArticles)
        name1 = name1.replacingOccurrences(of: " ", with: "")
        name1 = name1.replacingOccurrences(of: "-", with: "")
        
        var name2 = Database.si.name($1.itemName.lowercased(), ignoringArticles: ignoredArticles)
        name2 = name2.replacingOccurrences(of: " ", with: "")
        name2 = name2.replacingOccurrences(of: "-", with: "")
        
        return name1 < name2
    }
}
