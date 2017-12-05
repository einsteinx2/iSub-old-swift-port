//
//  UpdatePlaylistLoader.swift
//  iSub Beta
//
//  Created by Andres Felipe Rodriguez Bolivar on 11/28/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class UpdatePlaylistLoader: ApiLoader, ItemLoader {
    
    var playlist: Playlist?
    var associatedItem: Item?
    var items: [Item] {
        return playlist?.songs ?? []
    }
    
    init(with playlist: Playlist, and serverId: Int64) {
        self.playlist = playlist
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        guard let parameters = getRequestParameters() else {
            return nil
        }
        return URLRequest(subsonicAction: .updatePlaylist,
                          serverId: serverId,
                          parameters: parameters)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        return root.tag == "subsonic-response"
    }
    
    func loadModelsFromDatabase() -> Bool {
        guard let playlist = associatedItem as? Playlist else { return false }
        playlist.loadSubItems()
        return playlist.songs.count > 0
    }
}

private extension UpdatePlaylistLoader {
    
    func getRequestParameters() -> [String: Any]? {
        guard let playlist = playlist else {
            NSLog("there is no playlist to update")
            return nil
        }
        var parameters:[String:Any] = [:]
        parameters["playListId"] = playlist.playlistId
        parameters["name"] = playlist.name
        
        if let songsToAdd = getSongsToAdd() {
            parameters["songIdToAdd"] = songsToAdd
        }
        
        if let songsToRemove = getSongsToDelete() {
            parameters["songIndexToRemove"] = songsToRemove
        }
        
        return parameters
    }
    
    // TODO: missing implementation
    func getSongsToAdd() -> [String]? {
        return nil
    }
    
    // TODO: missing implementation
    func getSongsToDelete() -> [String]? {
        return nil
    }
}
