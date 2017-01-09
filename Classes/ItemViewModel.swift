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

class ItemViewModel : NSObject {
    
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
    
    var delegate: ItemViewModelDelegate?
    
    var topLevelController = false
    
    var shouldSetupRefreshControl: Bool {
        return !isBrowsingCache
    }
    
    fileprivate(set) var rootItem: ISMSItem?
    
    fileprivate(set) var items = [ISMSItem]()
    fileprivate(set) var folders = [ISMSFolder]()
    fileprivate(set) var artists = [ISMSArtist]()
    fileprivate(set) var albums = [ISMSAlbum]()
    fileprivate(set) var songs = [ISMSSong]()
    fileprivate(set) var playlists = [Playlist]()
    
    fileprivate(set) var songsDuration = 0
    fileprivate(set) var sectionIndexes = [SectionIndex]()
    fileprivate(set) var sectionIndexesSection = -1
    
    init(loader: ItemLoader) {
        self.loader = loader
        self.rootItem = loader.associatedObject as? ISMSItem
    }
    
    func loadModelsFromDatabase() -> Bool {
        let success = loader.loadModelsFromDatabase()
        if (success) {
            self.processModels()
        }
        
        return success
    }
    
    func loadModelsFromWeb(_ completion: LoadModelsCompletion?) {
        if loader.loaderState != .loading {
            loader.callbackBlock = { success, error, loader in
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
            
            loader.startLoad()
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
            case is ISMSFolder:   folders.append(item as! ISMSFolder)
            case is ISMSArtist:   artists.append(item as! ISMSArtist)
            case is ISMSAlbum:    albums.append(item as! ISMSAlbum)
            case is ISMSSong:     songs.append(item as! ISMSSong)
            case is Playlist:     playlists.append(item as! Playlist)
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
        
        let minAmountForIndexes = 50
        if folders.count >= minAmountForIndexes {
            sectionIndexes = SectionIndex.sectionIndexesForItems(folders)
            sectionIndexesSection = 0
        } else if artists.count >= minAmountForIndexes {
            sectionIndexes = SectionIndex.sectionIndexesForItems(artists)
            sectionIndexesSection = 1
        } else if albums.count >= minAmountForIndexes {
            sectionIndexes = SectionIndex.sectionIndexesForItems(albums)
            sectionIndexesSection = 2
        } else if songs.count >= minAmountForIndexes {
            sectionIndexes = SectionIndex.sectionIndexesForItems(songs)
            sectionIndexesSection = 3
        } else {
            sectionIndexes = []
            sectionIndexesSection = -1
        }
    }
    
    func cancelLoad() {
        loader.cancelLoad()
    }
    
    func loaderForFolder(_ folder: ISMSFolder) -> ItemLoader? {
        var folderLoader: ItemLoader?
        
        if let folderId = folder.folderId as? Int, let mediaFolderId = folder.mediaFolderId as? Int, let serverId = folder.serverId as? Int {
            if isBrowsingCache {
                folderLoader = CachedFolderLoader(folderId: folderId, serverId: serverId)
            } else {
                folderLoader = FolderLoader(folderId: folderId, mediaFolderId: mediaFolderId)
            }
        }
        
        return folderLoader
    }
    
    func loaderForArtist(_ artist: ISMSArtist) -> ItemLoader? {
        var artistLoader: ItemLoader?
        
        if let artistId = artist.artistId as? Int, let serverId = artist.serverId as? Int {
            if isBrowsingCache {
                artistLoader = CachedArtistLoader(artistId: artistId, serverId: serverId)
            } else {
                artistLoader = ArtistLoader(artistId: artistId)
            }
        }
        
        return artistLoader
    }
    
    func loaderForAlbum(_ album: ISMSAlbum) -> ItemLoader? {
        var albumLoader: ItemLoader?
        
        if let albumId = album.albumId as? Int, let serverId = album.serverId as? Int {
            if isBrowsingCache {
                albumLoader = CachedAlbumLoader(albumId: albumId, serverId: serverId)
            } else {
                albumLoader = AlbumLoader(albumId: albumId)
            }
        }
        
        return albumLoader
    }
    
    func playSong(atIndex index: Int) {
        // TODO: Implement a way to just switch play index when we're playing from the same array to save time
        //playAll(songs: viewModel.songs, playIndex: indexPath.row)
        PlayQueue.si.playSongs(songs, playIndex: index)
    }
    
    
}
