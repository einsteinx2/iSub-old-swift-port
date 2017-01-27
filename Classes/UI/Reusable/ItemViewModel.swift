//
//  ItemViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

protocol ItemViewModelDelegate {
    func itemsChanged()
    func loadingFinished()
    func loadingError(_ error: String)
}

typealias LoadModelsCompletion = (_ success: Bool, _ error: Error?) -> Void

class ItemViewModel: NSObject {
    
    fileprivate var loader: ItemLoader
    
    var isBrowsingCache: Bool {
        return loader is CachedDatabaseLoader
    }
    
    var isBrowsingFolder: Bool {
        return loader is FolderLoader
    }
    
    var isBrowsingAlbum: Bool {
        return loader is AlbumLoader
    }
    
    fileprivate(set) var songSortOrder = SongSortOrder.track
    var isShowTrackNumbers = true
    
    var delegate: ItemViewModelDelegate?
    
    var topLevelController = false
    var navigationTitle: String?
    
    var shouldSetupRefreshControl: Bool {
        return !isBrowsingCache
    }
    
    fileprivate(set) var rootItem: Item?
    
    fileprivate(set) var items = [Item]()
    fileprivate(set) var folders = [Folder]()
    fileprivate(set) var artists = [Artist]()
    fileprivate(set) var albums = [Album]()
    fileprivate(set) var songs = [Song]()
    fileprivate(set) var playlists = [Playlist]()
    
    fileprivate(set) var songsDuration = 0
    fileprivate(set) var sectionIndexes = [SectionIndex]()
    fileprivate(set) var sectionIndexesSection = -1
    
    init(loader: ItemLoader) {
        self.loader = loader
        self.rootItem = loader.associatedObject as? Item
        self.navigationTitle = self.rootItem?.itemName
        
        if let folder = loader.associatedObject as? Folder {
            self.songSortOrder = folder.songSortOrder
        }
    }
    
    func loadModelsFromDatabase() -> Bool {
        let success = loader.loadModelsFromDatabase()
        if (success) {
            self.processModels()
        }
        
        return success
    }
    
    func loadModelsFromWeb(_ completion: LoadModelsCompletion?) {
        if loader.state != .loading {
            loader.completionHandler = { success, error, loader in
                completion?(success, error)
                if success {
                    self.delegate?.loadingFinished()
                    
                    // May have some false positives, but prevents UI pauses
                    if self.items.count != self.loader.items.count {
                        self.processModels()
                        self.delegate?.itemsChanged()
                    }
                } else {
                    let errorString = error == nil ? "Unknown error" : error!.localizedDescription
                    self.delegate?.loadingError(errorString)
                }
            }
            
            loader.start()
        }
    }
    
    func processModels() {
        // Reset models
        folders.removeAll()
        artists.removeAll()
        albums.removeAll()
        songs.removeAll()
        playlists.removeAll()
        
        items = loader.items
        
        for item in items {
            switch item {
            case is Folder:   folders.append(item as! Folder)
            case is Artist:   artists.append(item as! Artist)
            case is Album:    albums.append(item as! Album)
            case is Song:     songs.append(item as! Song)
            case is Playlist: playlists.append(item as! Playlist)
            default: assertionFailure("WHY YOU NO ITEM?")
            }
        }
        
        var duration = 0
        for song in songs {
            if let songDuration = song.duration {
                duration = duration + Int(songDuration)
            }
        }
        songsDuration = duration
        
        sort(by: songSortOrder)
    }
    
    fileprivate func createSectionIndexes() {
        let minAmountForIndexes = 50
        if folders.count >= minAmountForIndexes {
            sectionIndexes = SectionIndex.sectionIndexes(forItems: folders)
            sectionIndexesSection = 0
        } else if artists.count >= minAmountForIndexes {
            sectionIndexes = SectionIndex.sectionIndexes(forItems: artists)
            sectionIndexesSection = 1
        } else if albums.count >= minAmountForIndexes {
            sectionIndexes = SectionIndex.sectionIndexes(forItems: albums)
            sectionIndexesSection = 2
        } else if songSortOrder != .track && songs.count >= minAmountForIndexes {
            switch songSortOrder {
            case .title:
                sectionIndexes = SectionIndex.sectionIndexes(forItems: songs)
            case .artist:
                sectionIndexes = SectionIndex.sectionIndexes(forNames: songs.map({$0.artistDisplayName ?? ""}))
            case .album:
                sectionIndexes = SectionIndex.sectionIndexes(forNames: songs.map({$0.albumDisplayName ?? ""}))
            default:
                break
            }
            sectionIndexesSection = 3
        } else {
            sectionIndexes = []
            sectionIndexesSection = -1
        }
    }
    
    func cancelLoad() {
        loader.cancel()
    }
    
    func loaderForFolder(_ folder: Folder) -> ItemLoader? {
        var folderLoader: ItemLoader?
        if isBrowsingCache {
            folderLoader = CachedFolderLoader(folderId: folder.folderId, serverId: folder.serverId)
        } else if let mediaFolderId = folder.mediaFolderId {
            folderLoader = FolderLoader(folderId: folder.folderId, mediaFolderId: mediaFolderId)
        }
        return folderLoader
    }
    
    func loaderForArtist(_ artist: Artist) -> ItemLoader? {
        var artistLoader: ItemLoader?
        if isBrowsingCache {
            artistLoader = CachedArtistLoader(artistId: artist.artistId, serverId: artist.serverId)
        } else{
            artistLoader = ArtistLoader(artistId: artist.artistId)
        }
        return artistLoader
    }
    
    func loaderForAlbum(_ album: Album) -> ItemLoader? {
        var albumLoader: ItemLoader?
        if isBrowsingCache {
            albumLoader = CachedAlbumLoader(albumId: album.albumId, serverId: album.serverId)
        } else {
            albumLoader = AlbumLoader(albumId: album.albumId)
        }
        return albumLoader
    }
    
    func loaderForPlaylist(_ playlist: Playlist) -> ItemLoader? {
        return PlaylistLoader(playlistId: playlist.playlistId)
    }
    
    func playSong(atIndex index: Int) {
        // TODO: Implement a way to just switch play index when we're playing from the same array to save time
        PlayQueue.si.playSongs(songs, playIndex: index)
    }
    
    func sort(by sortOrder: SongSortOrder) {
        self.songSortOrder = sortOrder
        // TODO: How can I assign to a constant here? It's not an Obj-C object...
        if let folder = loader.associatedObject as? Folder {
            folder.songSortOrder = sortOrder
            _ = folder.replace()
        }
        
        // TODO: Save this setting per folder id
        songs.sort { lhs, rhs -> Bool in
            switch sortOrder {
            case .track: return lhs.trackNumber ?? 0 < rhs.trackNumber ?? 0
            case .title: return lhs.title.lowercased() < rhs.title.lowercased()
            case .artist: return lhs.artistDisplayName?.lowercased() ?? "" < rhs.artistDisplayName?.lowercased() ?? ""
            case .album: return lhs.albumDisplayName?.lowercased() ?? "" < rhs.albumDisplayName?.lowercased() ?? ""
            }
        }
        createSectionIndexes()
        delegate?.itemsChanged()
    }
}
