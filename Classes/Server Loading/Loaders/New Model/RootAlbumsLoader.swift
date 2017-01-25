//
//  RootAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

final class RootAlbumsLoader: ApiLoader, ItemLoader {
    // 500 is the maximum size supported by Subsonic
    fileprivate let size = 500
    fileprivate var offset = 0
    
    var albums = [Album]()
    
    var associatedObject: Any?
    
    var items: [Item] {
        return albums
    }
    
    override func createRequest() -> URLRequest {
        let parameters = ["type": "alphabeticalByName", "offset": "\(offset)", "size":"\(size)"]
        return URLRequest(subsonicAction: .getAlbumList2, parameters: parameters)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var albumsTemp = [Album]()
        
        let serverId = SavedSettings.si.currentServerId
        root.iterate("albumList2.album") { album in
            if let anAlbum = Album(rxmlElement: album, serverId: serverId) {
                albumsTemp.append(anAlbum)
            }
        }
        
        if offset == 0 {
            albums = albumsTemp
        } else {
            albums.append(contentsOf: albumsTemp)
        }
        
        // Check if we have all albums, if not, keep paging
        if albumsTemp.count < size {
            persistModels()
            return true
        } else {
            offset += size
            self.state = .new
            self.start()
            return false
        }
    }
    
    func persistModels() {
        // Remove existing albums
        let serverId = SavedSettings.si.currentServerId
        _ = AlbumRepository.si.deleteAllAlbums(serverId: serverId)
        
        // Save the new albums
        albums.forEach({_ = $0.replace()})
    }
    
    func loadModelsFromDatabase() -> Bool {
        let serverId = SavedSettings.si.currentServerId
        let albumsTemp = AlbumRepository.si.allAlbums(serverId: serverId)
        if albumsTemp.count > 0 {
            albums = albumsTemp
            return true
        }
        return false
    }
}
