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
    
    static func ==(lhs: Server, rhs: Server) -> Bool {
        return lhs.url == rhs.url && lhs.username == rhs.username
    }
}

final class Server {
    static let testServerId = Int64.max
    static var testServer: Server {
        // Return model directly rather than storing in the database
        let testServer = Server(serverId: self.testServerId, type: .subsonic, url: "https://isubapp.com:9002", username: "isub-guest", basicAuth: false, legacyAuth: false)
        testServer.password = "1sub1snumb3r0n3"
        return testServer
    }
    
    let repository: ServerRepository
    
    let serverId: Int64
    let type: ServerType
    var url: String
    var username: String
    var basicAuth: Bool
    var legacyAuth: Bool
    
    fileprivate var passwordKey: String { return "\(serverId) - \(username)" }
    var password: String? {
        get {
            return KeychainWrapper.standard.string(forKey: passwordKey, withAccessibility: .afterFirstUnlock)
        }
        set {
            if let newValue = newValue {
                KeychainWrapper.standard.set(newValue, forKey: passwordKey, withAccessibility: .afterFirstUnlock)
            } else {
                KeychainWrapper.standard.removeObject(forKey: passwordKey, withAccessibility: .afterFirstUnlock)
            }
        }
    }
    
    init(serverId: Int64, type: ServerType, url: String, username: String, basicAuth: Bool, legacyAuth: Bool, repository: ServerRepository = ServerRepository.si) {
        self.serverId = serverId
        self.type = type
        self.url = url
        self.username = username
        self.basicAuth = basicAuth
        self.repository = repository
        self.legacyAuth = legacyAuth
    }
}
