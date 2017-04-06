//
//  FolderRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct FolderRepository: ItemRepository {
    static let si = FolderRepository()
    fileprivate let gr = GenericItemRepository.si
    
    let table = "folders"
    let cachedTable = "cachedFolders"
    let itemIdField = "folderId"
    
    func folder(folderId: Int64, serverId: Int64, loadSubItems: Bool = false) -> Folder? {
        return gr.item(repository: self, itemId: folderId, serverId: serverId, loadSubItems: loadSubItems)
    }
    
    func allFolders(serverId: Int64? = nil, isCachedTable: Bool = false) -> [Folder] {
        return gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    @discardableResult func deleteAllFolders(serverId: Int64?) -> Bool {
        return gr.deleteAllItems(repository: self, serverId: serverId)
    }
    
    func isPersisted(folder: Folder, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, item: folder, isCachedTable: isCachedTable)
    }
    
    func isPersisted(folderId: Int64, serverId: Int64, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, itemId: folderId, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func hasCachedSubItems(folder: Folder) -> Bool {
        return gr.hasCachedSubItems(repository: self, item: folder)
    }
    
    func delete(folder: Folder, isCachedTable: Bool = false) -> Bool {
        return gr.delete(repository: self, item: folder, isCachedTable: isCachedTable)
    }
    
    @discardableResult func deleteRootFolders(mediaFolderId: Int64?, serverId: Int64, isCachedTable: Bool = false) -> Bool {
        var success = true
        Database.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            var query = "DELETE FROM \(table) WHERE parentFolderId IS NULL AND serverId = ?"
            do {
                if let mediaFolderId = mediaFolderId {
                    query += " AND mediaFolderId = ?"
                    try db.executeUpdate(query, serverId, mediaFolderId)
                } else {
                    try db.executeUpdate(query, serverId)
                }
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func rootFolders(mediaFolderId: Int64? = nil, serverId: Int64? = nil, isCachedTable: Bool = false) -> [Folder] {
        var folders = [Folder]()
        Database.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            var query = "SELECT * FROM \(table) WHERE parentFolderId IS NULL"
            do {
                let result: FMResultSet
                if let mediaFolderId = mediaFolderId, let serverId = serverId {
                    query += " AND mediaFolderId = ? AND serverId = ?"
                    result = try db.executeQuery(query, mediaFolderId, serverId, serverId)
                } else if let mediaFolderId = mediaFolderId {
                    query += " AND mediaFolderId = ?"
                    result = try db.executeQuery(query, mediaFolderId)
                } else if let serverId = serverId {
                    query += " AND serverId = ?"
                    result = try db.executeQuery(query, serverId)
                } else {
                    result = try db.executeQuery(query)
                }
                
                while result.next() {
                    let folder = Folder(result: result)
                    folders.append(folder)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        return Sorting.subsonicSorted(items: folders, ignoredArticles: Sorting.ignoredArticles)
    }
    
    func folders(parentFolderId: Int64, serverId: Int64, isCachedTable: Bool = false) -> [Folder] {
        var folders = [Folder]()
        Database.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            let query = "SELECT * FROM \(table) WHERE parentFolderId = ? AND serverId = ?"
            do {
                let result = try db.executeQuery(query, parentFolderId, serverId)
                while result.next() {
                    let folder = Folder(result: result)
                    folders.append(folder)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        return folders
    }
    
    func replace(folder: Folder, isCachedTable: Bool = false) -> Bool {
        var success = true
        Database.si.write.inDatabase { db in
            do {
                let table = tableName(repository: self, isCachedTable: isCachedTable)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, folder.folderId, folder.serverId, n2N(folder.parentFolderId), n2N(folder.mediaFolderId), n2N(folder.coverArtId), folder.name, folder.songSortOrder.rawValue)
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func loadSubItems(folder: Folder) {
        folder.folders = folders(parentFolderId: folder.folderId, serverId: folder.serverId)
        folder.songs = SongRepository.si.songs(folderId: folder.folderId, serverId: folder.serverId)
    }
}

extension Folder: PersistedItem {
    class func item(itemId: Int64, serverId: Int64, repository: ItemRepository = FolderRepository.si) -> Item? {
        return (repository as? FolderRepository)?.folder(folderId: itemId, serverId: serverId)
    }
    
    var isPersisted: Bool {
        return repository.isPersisted(folder: self)
    }
    
    var hasCachedSubItems: Bool {
        return repository.hasCachedSubItems(folder: self)
    }
    
    @discardableResult func replace() -> Bool {
        return repository.replace(folder: self)
    }
    
    @discardableResult func cache() -> Bool {
        return repository.replace(folder: self, isCachedTable: true)
    }
    
    @discardableResult func delete() -> Bool {
        return repository.delete(folder: self)
    }
    
    @discardableResult func deleteCache() -> Bool {
        return repository.delete(folder: self, isCachedTable: true)
    }
    
    func loadSubItems() {
        repository.loadSubItems(folder: self)
    }
}
