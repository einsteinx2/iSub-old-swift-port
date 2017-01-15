//
//  RootPlaylistsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class RootPlaylistsLoader: ApiLoader, ItemLoader {
    var playlists = [Playlist]()
    
    var associatedObject: Any?
    
    var items: [ISMSItem] {
        return playlists
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getPlaylists)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var playlistsTemp = [Playlist]()
        
        let serverId = SavedSettings.si().currentServerId
        root.iterate("playlists.playlist") { playlist in
            let aPlaylist = Playlist(rxmlElement: playlist, serverId: serverId)
            playlistsTemp.append(aPlaylist)
        }
        playlistsTemp.sort(by: { $0.name < $1.name })
        playlists = playlistsTemp
        
        self.persistModels()
        
        self.finished()
        
        return true
    }
    
    func persistModels() {
        playlists.forEach({_ = $0.replace()})
    }
    
    func loadModelsFromDatabase() -> Bool {
        // TODO: Fix with new data model
        return false
    }
}
