//
//  PlaylistLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class PlaylistLoader: ApiLoader, PersistedItemLoader {
    let playlistId: Int64
    
    var songs = [Song]()
    
    var items: [Item] {
        return songs
    }
    
    var associatedItem: Item? {
        return PlaylistRepository.si.playlist(playlistId: playlistId, serverId: serverId)
    }
    
    init(playlistId: Int64, serverId: Int64) {
        self.playlistId = playlistId
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .getPlaylist, serverId: serverId, parameters: ["id": playlistId])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var songsTemp = [Song]()
        
        root.iterate("playlist.entry") { song in
            if let aSong = Song(rxmlElement: song, serverId: self.serverId) {
                songsTemp.append(aSong)
            }
        }
        songs = songsTemp
        
        persistModels()
        
        return true
    }
    
    func persistModels() {
        // Save the new songs
        songs.forEach({$0.replace()})
        
        // Update the playlist table
        // TODO: This will need to be rewritten to handle two way syncing
        if var playlist = associatedItem as? Playlist {
            playlist.overwriteSubItems()
        }
        
        // Make sure all artist and album records are created if needed
        var folderIds = Set<Int64>()
        var artistIds = Set<Int64>()
        var albumIds = Set<Int64>()
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
        if let playlist = associatedItem as? Playlist {
            playlist.loadSubItems()
            songs = playlist.songs
            return songs.count > 0
        }
        return false
    }

}
