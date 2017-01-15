//
//  FolderRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate let foldersTable = "folders"
fileprivate let cachedFoldersTable = "cachedFolders"

struct FolderRepository: ItemRepository {
    static var si: FolderRepository = FolderRepository()
    
    func folder(folderId: Int, serverId: Int, loadSubitems: Bool = false) -> Folder? {
        func runQuery(db: FMDatabase, table: String) -> Folder? {
            var folder: Folder? = nil
            let query = "SELECT * FROM \(table) WHERE folderId = ? AND serverId = ?"
            do {
                let result = try db.executeQuery(query, folderId, serverId)
                if result.next() {
                    folder = Folder(result: result)
                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
            return folder
        }
        
        var folder: Folder? = nil
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            folder = runQuery(db: db, table: foldersTable)
            if folder == nil {
                folder = runQuery(db: db, table: cachedFoldersTable)
            }
        }
        
        if loadSubitems, let folder = folder {
            folder.loadSubitems()
        }
        
        return folder
    }
    
    func folders(parentFolderId: Int, serverId: Int, isCachedTable: Bool) -> [Folder] {
        var folders = [Folder]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let table = isCachedTable ? cachedFoldersTable : foldersTable
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
    
    func allFolders(serverId: Int? = nil, isCachedTable: Bool = false) -> [Folder] {
        return [Folder]()
        let ignoredArticles = DatabaseSingleton.si().ignoredArticles()
        var folders = [Folder]()
        var foldersNumbers = [Folder]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let table = isCachedTable ? cachedFoldersTable : foldersTable
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
                    let folder = Folder(result: result)
                    let name = DatabaseSingleton.si().name(folder.name, ignoringArticles: ignoredArticles)
                    if let firstScalar = name.unicodeScalars.first {
                        if CharacterSet.letters.contains(firstScalar) {
                            folders.append(folder)
                        } else {
                            foldersNumbers.append(folder)
                        }
                    }
                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
        }
        
        folders = subsonicSorted(items: folders, ignoredArticles: ignoredArticles)
        folders.append(contentsOf: foldersNumbers)
        
        for folder in folders {
            folder.loadSubitems()
        }
        
        return folders
    }
    
    func deleteAllFolders(serverId: Int?) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                if let serverId = serverId {
                    let query = "DELETE FROM \(foldersTable) WHERE serverId = ?"
                    try db.executeUpdate(query, serverId)
                } else {
                    let query = "DELETE FROM \(foldersTable)"
                    try db.executeUpdate(query)
                }
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func isPersisted(folder: Folder, isCachedTable: Bool = false) -> Bool {
        let table = isCachedTable ? cachedFoldersTable : foldersTable
        let query = "SELECT COUNT(*) FROM \(table) WHERE folderId = ? AND serverId = ?"
        return DatabaseSingleton.si().songModelReadDbPool.boolForQuery(query, folder.folderId, folder.serverId)
    }
    
    func hasCachedSubItems(folder: Folder) -> Bool {
        let query = "SELECT COUNT(*) FROM cachedSongs WHERE folderId = ? AND serverId = ?"
        return DatabaseSingleton.si().songModelReadDbPool.boolForQuery(query, folder.folderId, folder.serverId)
    }
    
    func replace(folder: Folder, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = isCachedTable ? cachedFoldersTable : foldersTable
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, folder.folderId, folder.serverId, n2N(folder.parentFolderId), n2N(folder.mediaFolderId), n2N(folder.coverArtId), folder.name)
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func delete(folder: Folder, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = isCachedTable ? cachedFoldersTable : foldersTable
                let query = "DELETE FROM \(table) WHERE folderId = ? AND serverId = ?"
                try db.executeUpdate(query, folder.folderId, folder.serverId)
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func loadSubItems(folder: Folder) {
        folder.folders = self.folders(parentFolderId: folder.folderId, serverId: folder.serverId, isCachedTable: false)
        folder.songs = ISMSSong.songs(inFolder: folder.folderId, serverId: folder.serverId, cachedTable: false)
    }
}

extension Folder {
    convenience init(result: FMResultSet, repository: FolderRepository = FolderRepository.si) {
        let folderId        = result.long(forColumnIndex: 0)
        let serverId        = result.long(forColumnIndex: 1)
        let parentFolderId  = result.object(forColumnIndex: 2) as? Int
        let mediaFolderId  = result.object(forColumnIndex: 3) as? Int
        let coverArtId  = result.string(forColumnIndex: 4)
        let name        = result.string(forColumnIndex: 5) ?? ""
        self.init(folderId: folderId, serverId: serverId, parentFolderId: parentFolderId, mediaFolderId: mediaFolderId, coverArtId: coverArtId, name: name, repository: repository)
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
    
    func loadSubitems() {
        repository.loadSubItems(folder: self)
    }
}
