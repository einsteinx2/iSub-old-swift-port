//
//  RootAlbumsLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

final class RootAlbumsLoader: ApiLoader, RootItemLoader {
    // 500 is the maximum size supported by Subsonic
    fileprivate let size: Int = 500
    fileprivate var offset: Int = 0

    var mediaFolderId: Int64?

    var albums = [Album]()
    
    var associatedItem: Item?
    
    var items: [Item] {
        return albums
    }
    
    override func createRequest() -> URLRequest? {
        print("creating request")
        var parameters: [String: String] = ["type": "alphabeticalByName",
                                            "offset": "\(offset)",
                                            "size":"\(size)"]
        if let mediaFolderId = mediaFolderId, mediaFolderId >= 0 {
            parameters["musicFolderId"] = "\(mediaFolderId)"
        }
        return URLRequest(subsonicAction: .getAlbumList2, serverId: serverId, parameters: parameters)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var albumsTemp = [Album]()
        
        print("iterating album models")
        root.iterate("albumList2.album") { album in
            if let anAlbum = Album(rxmlElement: album, serverId: self.serverId) {
                albumsTemp.append(anAlbum)
            }
        }
        print("done iterating album models")
        
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
            print("loading more album models")
            offset += size
            self.state = .new
            self.start()
            return false
        }
    }
    
    func persistModels() {
        print("deleting existing album models")
        
        // Remove existing albums
        AlbumRepository.si.deleteAllAlbums(serverId: serverId)
        
        print("saving new album models")
        
        // Save the new albums
        albums.forEach({$0.replace()})
        
        print("done saving album models")
    }
    
    @discardableResult func loadModelsFromDatabase() -> Bool {
        print("loading album models from database")
        let albumsTemp = AlbumRepository.si.allAlbums(serverId: serverId)
        if albumsTemp.count > 0 {
            albums = albumsTemp
            print("done loading album models from database")
            return true
        }
        print("done loading album models from database")
        return false
    }
}
