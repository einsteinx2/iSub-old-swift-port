//
//  Server.swift
//  Pods
//
//  Created by Benjamin Baron on 2/11/16.
//
//

import Foundation

@objc
public enum ServerType: Int {
    case subsonic
    case iSubServer
    case waveBox
}

open class Server: NSObject, NSCopying, NSCoding { //, ISMSPersistedModel {
    
    open var serverId: Int
    open var type: ServerType
    open var url: String
    open var username: String
    
    // Passwords stored in the keychain
    open var password: String? {
        get {
            do {
                return try BCCKeychain.getPasswordString(forUsername: username, andServiceName: url)
            } catch {
                printError(error)
                return nil
            }
        }
        set(newValue) {
            do {
                if let newValue = newValue {
                    try BCCKeychain.storeUsername(username, andPasswordString: newValue, forServiceName: url, updateExisting: true)
                } else {
                    try BCCKeychain.deleteItem(forUsername: username, andServiceName: url)
                }
            } catch {
                printError(error)
            }
        }
    }
    
    // WaveBox Data Model
    open var lastQueryId: String?
    open var uuid: String?

    public init?(itemId: Int) {
        var serverId: Int?, type: Int?, url: String?, username: String?, lastQueryId: String?, uuid: String?
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            do {
                let query = "SELECT * FROM servers WHERE serverId = ?"
                let result = try db.executeQuery(query, itemId)
                if result.next() {
                    serverId = result.long(forColumnIndex: 0)
                    type = result.long(forColumnIndex: 1)
                    url = result.string(forColumnIndex: 2)
                    username = result.string(forColumnIndex: 3)
                    lastQueryId = result.string(forColumnIndex: 4)
                    uuid = result.string(forColumnIndex: 5)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        if let serverId = serverId, let type = type, let url = url, let username = username {
            self.serverId = serverId
            self.type = ServerType(rawValue: type)!
            self.url = url
            self.username = username
            self.lastQueryId = lastQueryId
            self.uuid = uuid
            super.init()
        } else {
            self.serverId = -1; self.type = .subsonic; self.url = ""; self.username = ""
            super.init()
            return nil
        }
    }
    
    public init(_ result: FMResultSet) {
        self.serverId = result.long(forColumnIndex: 0)
        self.type = ServerType(rawValue: result.long(forColumnIndex: 1))!
        self.url = result.string(forColumnIndex: 2)
        self.username = result.string(forColumnIndex: 3)
        self.lastQueryId = result.string(forColumnIndex: 4)
        self.uuid = result.string(forColumnIndex: 5)
        
        super.init()
    }
    
    // Save new server
    public init?(type: ServerType, url: String, username: String, lastQueryId: String?, uuid: String?, password: String) {
        self.type = type
        self.url = url
        self.username = username
        self.lastQueryId = lastQueryId
        self.uuid = uuid
        
        var success = true
        var serverId = -1
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let query = "INSERT INTO servers VALUES (?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, NSNull(), type.rawValue, url, username, n2N(lastQueryId), n2N(uuid))
                
                serverId = db.longForQuery("SELECT last_insert_rowid()")
            } catch {
                printError(error)
                success = false
            }
        }
        
        self.serverId = serverId
        super.init()
        
        if success {
            self.password = password
        } else {
            return nil
        }
    }
    
    public init(serverId: Int, type: ServerType, url: String, username: String, lastQueryId: String?, uuid: String?) {
        self.serverId = serverId
        self.type = type
        self.url = url
        self.username = username
        self.lastQueryId = lastQueryId
        self.uuid = uuid
    }
    
    open static func allServers() -> [Server] {
        var servers = [Server]()
        
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            do {
                let query = "SELECT * FROM servers"
                let result = try db.executeQuery(query)
                while result.next() {
                    servers.append(Server(result))
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        return servers
    }
    
    open static var testServerId: Int {
        return NSIntegerMax
    }
    
    open static var testServer: Server {
        // Return model directly rather than storing in the database
        let testServer = Server(serverId: self.testServerId, type: .subsonic, url: "https://isubapp.com:9002", username: "isub-guest", lastQueryId: nil, uuid: nil)
        testServer.password = "1sub1snumb3r0n3"
        return testServer
    }
    
    // MARK: - ISMSItem -
    
    open var itemId: NSNumber? {
        return NSNumber(value: self.serverId as Int)
    }
    
    open var itemName: String? {
        return self.url
    }
    
    // MARK: - ISMSPersistantItem -
    
    open func insertModel() -> Bool {
        // TODO: Fill this in
        return false
    }
    
    open func replaceModel() -> Bool {
        // TODO: Fill this in
        return false
    }
    
    open func deleteModel() -> Bool {
        // TODO: Fill this in
        return false
    }
    
    open func reloadSubmodels() {
        // No submodules
    }
    
    // MARK: - NSCoding -
    
    open func encode(with aCoder: NSCoder) {
        aCoder.encode(self.serverId,      forKey: "serverId")
        aCoder.encode(self.type.rawValue, forKey: "type")
        aCoder.encode(self.url,           forKey: "url")
        aCoder.encode(self.username,      forKey: "username")
        aCoder.encode(self.lastQueryId,   forKey: "lastQueryId")
        aCoder.encode(self.uuid,          forKey: "uuid")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.serverId    = aDecoder.decodeInteger(forKey: "playlistId")
        self.type        = ServerType(rawValue: aDecoder.decodeInteger(forKey: "type"))!
        self.url         = aDecoder.decodeObject(forKey: "url") as! String
        self.username    = aDecoder.decodeObject(forKey: "username") as! String
        self.lastQueryId = aDecoder.decodeObject(forKey: "lastQueryId") as? String
        self.uuid        = aDecoder.decodeObject(forKey: "uuid") as? String
    }
    
    // MARK: - NSCopying -
    
    open func copy(with zone: NSZone?) -> Any {
        return Server(serverId: self.serverId, type: self.type, url: self.url, username: self.username, lastQueryId: self.lastQueryId, uuid: self.uuid)
    }
}

// MARK: - Equality -

extension Server {
    open override func isEqual(_ object: Any?) -> Bool {
        if let object = object as? Server {
            return self.url == object.url && self.username == object.username
        } else {
            return false
        }
    }
    
    open override var hash: Int {
        return (self.url + self.username).hashValue
    }
    
    open override var hashValue: Int {
        return (self.url + self.username).hashValue
    }
}

public func ==(lhs: Server, rhs: Server) -> Bool {
    return lhs.url == rhs.url && lhs.username == rhs.username
}
