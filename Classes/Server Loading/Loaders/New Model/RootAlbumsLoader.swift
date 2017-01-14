//
//  RootAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

class RootAlbumsLoader: ApiLoader, ItemLoader {
    var albums = [ISMSAlbum]()
    
    var associatedObject: Any?
    
    var items: [ISMSItem] {
        return albums
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getAlbumList2, parameters: ["type": "alphabeticalByName"])
    }
    
    override func processResponse(root: RXMLElement) {
        var albumsTemp = [ISMSAlbum]()
        
        let serverId = SavedSettings.si().currentServerId
        root.iterate("albumList2.album") { album in
            let anAlbum = ISMSAlbum(rxmlElement: album, serverId: serverId)
            albumsTemp.append(anAlbum)
        }
        
        albums = albumsTemp
        
        self.persistModels()
    }
    
    func persistModels() {
        // Remove existing artists
        let serverId = SavedSettings.si().currentServerId as NSNumber
        ISMSAlbum.deleteAllAlbums(withServerId: serverId)
        
        // Save the new artists
        albums.forEach({$0.insert()})
    }
    
    func loadModelsFromDatabase() -> Bool {
        let serverId = SavedSettings.si().currentServerId as NSNumber
        let albumsTemp = ISMSAlbum.allAlbums(withServerId: serverId)
        if albumsTemp.count > 0 {
            albums = albumsTemp
            return true
        }
        return false
    }
}
