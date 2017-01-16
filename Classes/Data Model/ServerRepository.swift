//
//  ServerRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct ServerRepository: ItemRepository {
    static let si = ServerRepository()
    fileprivate let gr = GenericItemRepository.si
    
    let table = "servers"
    let cachedTable = "servers"
    let itemIdField = "serverId"
    
    func server(serverId: Int64) -> Server? {
        return gr.item(repository: self, itemId: serverId)
    }
    
    func allServers() -> [Server] {
        return gr.allItems(repository: self)
    }
    
    func isPersisted(server: Server) -> Bool {
        return gr.isPersisted(repository: self, item: server)
    }
    
    func isPersisted(serverId: Int64) -> Bool {
        return gr.isPersisted(repository: self, itemId: serverId, serverId: serverId)
    }
    
    func delete(server: Server) -> Bool {
        return gr.delete(repository: self, item: server)
    }
    
    func replace(server: Server) -> Bool {
        var success = true
        DatabaseSingleton.si.write.inDatabase { db in
            do {
                let query = "REPLACE INTO \(self.table) VALUES (?, ?, ?, ?)"
                try db.executeUpdate(query, server.serverId, server.type.rawValue, server.url, server.username)
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    // Save new server
    func server(type: ServerType, url: String, username: String, password: String) -> Server? {
        var success = true
        var serverId: Int64 = -1
        DatabaseSingleton.si.write.inDatabase { db in
            do {
                let query = "INSERT INTO servers VALUES (?, ?, ?, ?)"
                try db.executeUpdate(query, NSNull(), type.rawValue, url, username)
                serverId = db.lastInsertRowId()
            } catch {
                printError(error)
                success = false
            }
        }
        
        if success && serverId >= 0 {
            let server = Server(serverId: serverId, type: type, url: url, username: username)
            server.password = password
            return server
        }
        return nil
    }
}

extension Server: PersistedItem {
    class func item(itemId: Int64, serverId: Int64, repository: ItemRepository = ServerRepository.si) -> Item? {
        return (repository as? ServerRepository)?.server(serverId: itemId)
    }
    
    var isPersisted: Bool {
        return repository.isPersisted(server: self)
    }
    
    var hasCachedSubItems: Bool {
        // Not applicable
        return false
    }
    
    func replace() -> Bool {
        return repository.replace(server: self)
    }
    
    func cache() -> Bool {
        // Not applicable
        return false
    }
    
    func delete() -> Bool {
        return repository.delete(server: self)
    }
    
    func deleteCache() -> Bool {
        // Not applicable
        return false
    }
    
    func loadSubItems() {
        // No sub items
    }
}
