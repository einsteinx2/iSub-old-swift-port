//
//  FolderLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class FolderLoader: ApiLoader, ItemLoader {
    let folderId: Int
    let mediaFolderId: Int
    
    var folders = [ISMSFolder]()
    var songs = [ISMSSong]()
    var songsDuration = 0.0
    
    var items: [ISMSItem] {
        return folders as [ISMSItem] + songs as [ISMSItem]
    }
    
    init(folderId: Int, mediaFolderId: Int) {
        self.folderId = folderId
        self.mediaFolderId = mediaFolderId
        super.init()
    }
    
    override func createRequest() -> URLRequest {
        return URLRequest(subsonicAction: .getMusicDirectory, parameters: ["id": folderId])
    }
    
    override func processResponse(root: RXMLElement) {
        var songsDurationTemp = 0.0
        var foldersTemp = [ISMSFolder]()
        var songsTemp = [ISMSSong]()
        
        let serverId = SavedSettings.si().currentServerId
        root.iterate("directory.child") { child in
            if (child.attribute("isDir") as NSString).boolValue {
                if child.attribute("title") != ".AppleDouble" {
                    let aFolder = ISMSFolder(rxmlElement: child, serverId: serverId, mediaFolderId: self.mediaFolderId)
                    foldersTemp.append(aFolder)
                }
            } else {
                let aSong = ISMSSong(rxmlElement: child, serverId: serverId)
                if let duration = aSong.duration as? Double {
                    songsDurationTemp += duration
                }
                songsTemp.append(aSong)
            }
        }
        folders = foldersTemp
        songs = songsTemp
        songsDuration = songsDurationTemp
        
        // Persist associated object model if needed
        if !ISMSAlbum.isPersisted(NSNumber(value: folderId), serverId: NSNumber(value: serverId)) {
            if let element = root.child("directory") {
                let folder = ISMSFolder(rxmlElement: element, serverId: serverId, mediaFolderId: mediaFolderId)
                folder.replace()
            }
        }
        
        self.persistModels()
    }
    
    func persistModels() {
        folders.forEach({$0.replace()})
        songs.forEach({$0.replace()})
        
        if let folder = associatedObject as? ISMSFolder {
            // Persist if needed
            folder.replace()
            
            // Add to cache table if needed
            if let folder = associatedObject as? ISMSFolder, folder.hasCachedSongs() {
                folder.cacheModel()
            }
        }
        
        // Make sure all artist and album records are created if needed
        var artistIds = Set<Int>()
        var albumIds = Set<Int>()
        for song in songs {
            if let artist = song.artist, let artistId = artist.artistId as? Int, !artist.isPersisted {
                artistIds.insert(artistId)
            } else if song.artist == nil, let artistId = song.artistId as? Int {
                artistIds.insert(artistId)
            }
            
            if let album = song.album, let albumId = album.albumId as? Int, !album.isPersisted {
                albumIds.insert(albumId)
            } else if song.album == nil, let albumId = song.albumId as? Int {
                albumIds.insert(albumId)
            }
        }
        
        // Load any needed models (ensure that artists load first)
        for artistId in artistIds {
            let loader = ArtistLoader(artistId: artistId)
            let operation = ItemLoaderOperation(loader: loader)
            ApiLoader.backgroundLoadingQueue.addOperation(operation)
        }
        
        for albumId in albumIds {
            let loader = AlbumLoader(albumId: albumId)
            let operation = ItemLoaderOperation(loader: loader)
            ApiLoader.backgroundLoadingQueue.addOperation(operation)
        }
    }
    
    func loadModelsFromDatabase() -> Bool {
        if let folder = associatedObject as? ISMSFolder {
            folder.reloadSubmodels()
            folders = folder.folders
            songs = folder.songs
            songsDuration = songs.reduce(0.0) { totalDuration, song -> Double in
                if let duration = song.duration as? Double {
                    return totalDuration + duration
                }
                return totalDuration
            }
            return items.count > 0
        }
        return false
    }
    
    var associatedObject: Any? {
        return ISMSFolder(folderId: folderId, serverId: SavedSettings.si().currentServerId, loadSubmodels: false)
    }
}
