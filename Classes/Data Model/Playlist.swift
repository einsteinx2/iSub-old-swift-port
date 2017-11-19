//
//  Playlist.swift
//  LibSub
//
//  Created by Benjamin Baron on 2/10/16.
//
//

import Foundation

extension Playlist: Item, Equatable {
    var itemId: Int64 { return playlistId }
    var itemName: String { return name }
}

final class Playlist {
    let repository: PlaylistRepository
    
    var playlistId: Int64
    var serverId: Int64
    var name: String
    var coverArtId: String?
    
    // TODO: See if we should always load these from database rather than using the loadSubItems concept from the other models
    var songs = [Song]()
    
    init(playlistId: Int64, serverId: Int64, name: String, coverArtId: String?, repository: PlaylistRepository = PlaylistRepository.si) {
        self.playlistId = playlistId
        self.serverId = serverId
        self.name = name
        self.coverArtId = coverArtId
        self.repository = repository
    }
}

// Notifications
extension Playlist {
    struct Notifications {
        static let playlistChanged = Notification.Name("playlistChanged")
        
        struct Keys {
            static let playlistId = "playlistId"
        }
    }
    
    func notifyPlaylistChanged() {
        NotificationCenter.postOnMainThread(name: Playlist.Notifications.playlistChanged, object: nil, userInfo: [Notifications.Keys.playlistId: playlistId])
    }
}
