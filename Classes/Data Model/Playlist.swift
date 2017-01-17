//
//  Playlist.swift
//  LibSub
//
//  Created by Benjamin Baron on 2/10/16.
//
//

// Important note: Playlist table song indexes are 0 based to better interact with Swift/ObjC arrays.
// Normally SQLite table primary key fields start at 1 rather than 0. We force it to start at 0
// by inserting the first record with a manually chosen songIndex of 0.

import Foundation

extension Playlist: Item {
    var itemId: Int64 { return playlistId }
    var itemName: String { return name }
}

@objc class Playlist: NSObject {
    
    struct Notifications {
        static let playlistChanged = "playlistChanged"
        
        struct Keys {
            static let playlistId = "playlistId"
        }
    }
    
    func notifyPlaylistChanged() {
        NotificationCenter.postNotificationToMainThread(withName: Playlist.Notifications.playlistChanged, object: nil, userInfo: [Notifications.Keys.playlistId: self.playlistId])
    }
    
    let repository: PlaylistRepository
    
    var playlistId: Int64
    var serverId: Int64
    var name: String
    
    // TODO: See if we should always load these from database rather than using the loadSubItems concept from the other models
    var songs = [Song]()
    
    init(playlistId: Int64, serverId: Int64, name: String, repository: PlaylistRepository = PlaylistRepository.si) {
        self.playlistId = playlistId
        self.serverId = serverId
        self.name = name
        self.repository = repository
    }
    
    init?(rxmlElement element: RXMLElement, serverId: Int64, repository: PlaylistRepository = PlaylistRepository.si) {
        guard let playlistId = element.attribute(asInt64Optional: "id") else {
            return nil
        }
        
        self.playlistId = playlistId
        self.serverId = serverId
        self.name = element.attribute("name") ?? ""
        self.repository = repository
    }

    required init(result: FMResultSet, repository: ItemRepository = PlaylistRepository.si) {
        self.playlistId = result.longLongInt(forColumnIndex: 0)
        self.serverId = result.longLongInt(forColumnIndex: 1)
        self.name = result.string(forColumnIndex: 2)
        self.repository = repository as! PlaylistRepository
    }
    
    static func ==(lhs: Playlist, rhs: Playlist) -> Bool {
        return lhs.playlistId == rhs.playlistId
    }
}
