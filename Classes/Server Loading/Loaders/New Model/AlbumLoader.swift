//
//  AlbumLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class AlbumLoader: ApiLoader, ItemLoader {
    let albumId: Int64
    
    var songs = [Song]()
    
    var items: [Item] {
        return songs
    }
    
    init(albumId: Int64) {
        self.albumId = albumId
        super.init()
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getAlbum, parameters: ["id": albumId])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var songsTemp = [Song]()
        
        let serverId = SavedSettings.si.currentServerId
        root.iterate("album.song") { song in
            if let aSong = Song(rxmlElement: song, serverId: serverId) {
                songsTemp.append(aSong)
            }
        }
        songs = songsTemp
        
        // Persist associated object model if needed
        if !AlbumRepository.si.isPersisted(albumId: albumId, serverId: serverId) {
            if let element = root.child("album"), let album = Album(rxmlElement: element, serverId: serverId) {
                _ = album.replace()
            }
        }
        
        persistModels()
        
        return true
    }
    
    func persistModels() {
        // Save the new songs
        songs.forEach({_ = $0.replace()})
        
        // Add to cache table if needed
        if let album = associatedObject as? Album, album.hasCachedSubItems {
            _ = album.cache()
        }
        
        // Make sure all folder records are created if needed
        var folderIds = Set<Int64>()
        for song in songs {
            func performOperation(folderId: Int64, mediaFolderId: Int64) {
                if !folderIds.contains(folderId) {
                    folderIds.insert(folderId)
                    let loader = FolderLoader(folderId: folderId, mediaFolderId: mediaFolderId)
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
    
    func loadModelsFromDatabase() -> Bool {
        if let album = associatedObject as? Album {
            album.loadSubItems()
            songs = album.songs
            return songs.count > 0
        }
        return false
    }
    
    var associatedObject: Any? {
        let serverId = SavedSettings.si.currentServerId
        return AlbumRepository.si.album(albumId: albumId, serverId: serverId)
    }
}
