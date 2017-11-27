//
//  CreatePlaylistLoader.swift
//  iSub Beta
//
//  Created by Felipe Rolvar on 26/11/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CreatePlaylistLoader: ApiLoader, ItemLoader {
    
    private let playlistId: Int64?
    private var songs = [Song]()
    var playlistName: String
    
    var items: [Item] {
        return songs
    }
    
    var associatedItem: Item? {
        return PlaylistRepository.si.playlist(name: playlistName, serverId: serverId)
    }
    
    init(with name: String, and serverId: Int64) {
        self.playlistName = name
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .createPlaylist,
                          serverId: serverId,
                          parameters: ["name": playlistName,
                                       "songId" : items.map { $0.itemId }])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        songs.removeAll()
        root.iterate("playlist.entry") {
            guard let song = Song(rxmlElement: $0, serverId: serverId) else { continue }
            songs.append(song)
        }
        persistModels()
        return true
    }
    
    // TODO: Explanation of this snipet
    func persistModels() {
        // Save the new songs
        songs.forEach { $0.replace() }
        
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
        guard let playlist = associatedItem as? Playlist else { return false }
        playlist.loadSubItems()
        songs = playlist.songs
        return songs.count > 0
    }
    
}
