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
    let itemId = "folderId"
    
    func folder(folderId: Int, serverId: Int, loadSubItems: Bool = false) -> Folder? {
        return gr.item(repository: self, itemId: folderId, serverId: serverId, loadSubItems: loadSubItems)
    }
    
    func allFolders(serverId: Int? = nil, isCachedTable: Bool = false) -> [Folder] {
        return gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func deleteAllFolders(serverId: Int?) -> Bool {
        return gr.deleteAllItems(repository: self, serverId: serverId)
    }
    
    func isPersisted(folder: Folder, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, item: folder, isCachedTable: isCachedTable)
    }
    
    func hasCachedSubItems(folder: Folder) -> Bool {
        return gr.hasCachedSubItems(repository: self, item: folder)
    }
    
    func delete(folder: Folder, isCachedTable: Bool = false) -> Bool {
        return gr.delete(repository: self, item: folder, isCachedTable: isCachedTable)
    }
    
    func folders(parentFolderId: Int, serverId: Int, isCachedTable: Bool) -> [Folder] {
        var folders = [Folder]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
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
                print("DB Error: \(error)")
            }
        }
        return folders
    }
    
    func replace(folder: Folder, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = tableName(repository: self, isCachedTable: isCachedTable)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, folder.folderId, folder.serverId, n2N(folder.parentFolderId), n2N(folder.mediaFolderId), n2N(folder.coverArtId), folder.name)
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func loadSubItems(folder: Folder) {
        folder.folders = folders(parentFolderId: folder.folderId, serverId: folder.serverId, isCachedTable: false)
        folder.songs = ISMSSong.songs(inFolder: folder.folderId, serverId: folder.serverId, cachedTable: false)
    }
}

extension Folder: PersistedItem {
    var isPersisted: Bool {
        return repository.isPersisted(folder: self)
    }
    
    var hasCachedSubItems: Bool {
        return repository.hasCachedSubItems(folder: self)
    }
    
    func replace() -> Bool {
        return repository.replace(folder: self)
    }
    
    func cache() -> Bool {
        return repository.replace(folder: self, isCachedTable: true)
    }
    
    func delete() -> Bool {
        return repository.delete(folder: self)
    }
    
    func loadSubItems() {
        repository.loadSubItems(folder: self)
    }
}
