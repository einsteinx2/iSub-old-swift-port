//
//  Server.swift
//  Pods
//
//  Created by Benjamin Baron on 2/11/16.
//
//

import Foundation

enum ServerType: Int {
    case subsonic = 1
    case waveBox  = 2
}

extension Server: Item, Equatable {
    var itemId: Int64 { return serverId }
    var itemName: String { return url }
    var coverArtId: String? { return nil }
}

final class Server {
    static let testServerId = Int64.max
    static var testServer: Server {
        // Return model directly rather than storing in the database
        let testServer = Server(serverId: self.testServerId, type: .subsonic, url: "https://isubapp.com:9002", username: "isub-guest", basicAuth: false)
        testServer.password = "1sub1snumb3r0n3"
        return testServer
    }
    
    let repository: ServerRepository
    
    let serverId: Int64
    let type: ServerType
    var url: String
    var username: String
    var basicAuth: Bool
    
    // Passwords stored in the keychain
    var password: String? {
        get {
            do {
                return try BCCKeychain.getPasswordString(forUsername: username, andServiceName: url)
            } catch {
                printError(error)
                return nil
            }
        }
        set {
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
    
    init(serverId: Int64, type: ServerType, url: String, username: String, basicAuth: Bool, repository: ServerRepository = ServerRepository.si) {
        self.serverId = serverId
        self.type = type
        self.url = url
        self.username = username
        self.basicAuth = basicAuth
        self.repository = repository
    }
    
    // This must be marked required or we get a crash due to a Swift bug
    required init(result: FMResultSet, repository: ItemRepository) {
        self.serverId = result.longLongInt(forColumnIndex: 0)
        self.type = ServerType(rawValue: result.long(forColumnIndex: 1)) ?? .subsonic
        self.url = result.string(forColumnIndex: 2) ?? ""
        self.username = result.string(forColumnIndex: 3) ?? ""
        self.basicAuth = result.bool(forColumnIndex: 4)
        self.repository = repository as! ServerRepository
    }
    
    static func ==(lhs: Server, rhs: Server) -> Bool {
        return lhs.url == rhs.url && lhs.username == rhs.username
    }
}

// ObjC shim
extension Server {
    static func server(serverId: Int64) -> Server? {
        return ServerRepository.si.server(serverId: serverId)
    }
}
