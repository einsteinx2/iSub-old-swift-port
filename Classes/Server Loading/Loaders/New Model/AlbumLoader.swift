//
//  AlbumLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class AlbumLoader: ApiLoader, PersistedItemLoader {
    let albumId: Int64
    
    var songs = [Song]()
    
    var items: [Item] {
        return songs
    }
    
    init(albumId: Int64, serverId: Int64) {
        self.albumId = albumId
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .getAlbum, serverId: serverId, parameters: ["id": albumId])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var songsTemp = [Song]()
        
        root.iterate("album.song") { song in
            if let aSong = Song(rxmlElement: song, serverId: self.serverId) {
                songsTemp.append(aSong)
            }
        }
        songs = songsTemp
        
        // Persist associated object model if needed
        if !AlbumRepository.si.isPersisted(albumId: albumId, serverId: serverId) {
            if let element = root.child("album"), let album = Album(rxmlElement: element, serverId: serverId) {
                album.replace()
            }
        }
        
        persistModels()
        
        return true
    }
    
    func persistModels() {
        // Save the new songs
        songs.forEach({$0.replace()})
        
        // Add to cache table if needed
        if let album = associatedItem as? Album, album.hasCachedSubItems {
            album.cache()
        }
        
        // Make sure all folder records are created if needed
        var folderIds = Set<Int64>()
        for song in songs {
            func performOperation(folderId: Int64, mediaFolderId: Int64) {
                if !folderIds.contains(folderId) {
                    folderIds.insert(folderId)
                    let loader = FolderLoader(folderId: folderId, serverId: serverId, mediaFolderId: mediaFolderId)
                    let operation = ItemLoaderOperation(loader: loader)
                    ApiLoader.backgroundLoadingQueue.addOperation(operation)
                }
            }
            
            if let folder = song.folder, let mediaFolderId = folder.mediaFolderId, !folder.isPersisted {
                performOperation(folderId: folder.folderId, mediaFolderId: mediaFolderId)
            } else if song.folder == nil, let folderId = song.folderId, let mediaFolderId = song.mediaFolderId {
                performOperation(folderId: folderId, mediaFolderId: mediaFolderId)
            }
        }
    }
    
    @discardableResult func loadModelsFromDatabase() -> Bool {
        if let album = associatedItem as? Album {
            album.loadSubItems()
            songs = album.songs
            return songs.count > 0
        }
        return false
    }
    
    var associatedItem: Item? {
        return AlbumRepository.si.album(albumId: albumId, serverId: serverId)
    }
}
