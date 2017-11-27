//
//  CreatePlaylistLoader.swift
//  iSub Beta
//
//  Created by Felipe Rolvar on 26/11/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CreatePlaylistLoader: ApiLoader, ItemLoader {
    
    private var songs = [Song]()
    var playlistName: String
    
    var items: [Item] {
        return songs
    }
    
    var associatedItem: Item? {
        return PlaylistRepository.si.playlist(name: playlistName, serverId: serverId)
    }
    
    init(with name: String, and serverId: Int64) {
        self.playlistName = name
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .createPlaylist,
                          serverId: serverId,
                          parameters: ["name": playlistName,
                                       "songId" : items.map { $0.itemId }])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        songs.removeAll()
        root.iterate("playlist.entry") { [weak self] in
            guard let serverId = self?.serverId,
                let song = Song(rxmlElement: $0, serverId: serverId) else {
                return
            }
            self?.songs.append(song)
        }
        return true
    }
    
    @discardableResult func loadModelsFromDatabase() -> Bool {
        guard let playlist = associatedItem as? Playlist else { return false }
        playlist.loadSubItems()
        songs = playlist.songs
        return songs.count > 0
    }
    
    // MARK: - Nothing to implement
    func persistModels() { }
}
