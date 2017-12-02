//
//  FolderLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class FolderLoader: ApiLoader, PersistedItemLoader {
    let folderId: Int64
    let mediaFolderId: Int64
    
    var folders = [Folder]()
    var songs = [Song]()
    var songsDuration = 0
    
    var items: [Item] {
        return folders as [Item] + songs as [Item]
    }
    
    init(folderId: Int64, serverId: Int64, mediaFolderId: Int64 = 0) {
        self.folderId = folderId
        self.mediaFolderId = mediaFolderId
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .getMusicDirectory, serverId: serverId, parameters: ["id": folderId])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var songsDurationTemp = 0
        var foldersTemp = [Folder]()
        var songsTemp = [Song]()
        
        root.iterate("directory.child") { child in
            if (child.attribute("isDir") as NSString).boolValue {
                if child.attribute("title") != ".AppleDouble" {
                    if let aFolder = Folder(rxmlElement: child, serverId: self.serverId, mediaFolderId: self.mediaFolderId) {
                        foldersTemp.append(aFolder)
                    }
                }
            } else {
                if let aSong = Song(rxmlElement: child, serverId: self.serverId) {
                    if let duration = aSong.duration {
                        songsDurationTemp += duration
                    }
                    songsTemp.append(aSong)
                }
            }
        }
        folders = foldersTemp
        songs = songsTemp
        songsDuration = songsDurationTemp
        
        // Persist associated object model if needed
        if !FolderRepository.si.isPersisted(folderId: folderId, serverId: serverId) {
            if let element = root.child("directory"), let folder = Folder(rxmlElement: element, serverId: serverId, mediaFolderId: mediaFolderId) {
                folder.replace()
            }
        }
        persistModels()
        
        return true
    }
    
    func persistModels() {
        folders.forEach({$0.replace()})
        songs.forEach({$0.replace()})
        
        if let folder = associatedItem as? Folder {
            // Persist if needed
            folder.replace()
            
            // Add to cache table if needed
            if let folder = associatedItem as? Folder, folder.hasCachedSubItems {
                folder.cache()
            }
        }
        
        // Make sure all artist and album records are created if needed
        var artistIds = Set<Int64>()
        var albumIds = Set<Int64>()
        for song in songs {
            if let artist = song.artist, !artist.isPersisted {
                artistIds.insert(artist.artistId)
            } else if song.artist == nil, let artistId = song.artistId {
                artistIds.insert(artistId)
            }
            
            if let album = song.album, !album.isPersisted {
                albumIds.insert(album.albumId)
            } else if song.album == nil, let albumId = song.albumId {
                albumIds.insert(albumId)
            }
        }
        
        // Load any needed models (ensure that artists load first)
        for artistId in artistIds {
            let loader = ArtistLoader(artistId: artistId, serverId: serverId)
            let operation = ItemLoaderOperation(loader: loader)
            ApiLoader.backgroundLoadingQueue.addOperation(operation)
        }
        
        for albumId in albumIds {
            let loader = AlbumLoader(albumId: albumId, serverId: serverId)
            let operation = ItemLoaderOperation(loader: loader)
            ApiLoader.backgroundLoadingQueue.addOperation(operation)
        }
    }
    
    @discardableResult func loadModelsFromDatabase() -> Bool {
        if let folder = associatedItem as? Folder {
            folder.loadSubItems()
            folders = folder.folders
            songs = folder.songs
            songsDuration = songs.reduce(0) { totalDuration, song -> Int in
                if let duration = song.duration {
                    return totalDuration + duration
                }
                return totalDuration
            }
            return items.count > 0
        }
        return false
    }
    
    var associatedItem: Item? {
        return FolderRepository.si.folder(folderId: folderId, serverId: serverId)
    }
}
