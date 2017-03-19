//
//  ItemViewModel.swift
//  iSub
//
//  Created by Benjamin Baron on 2/1/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

protocol ItemViewModelDelegate {
    func itemsChanged(viewModel: ItemViewModel)
    func loadingFinished(viewModel: ItemViewModel)
    func loadingError(_ error: String, viewModel: ItemViewModel)
    func presentActionSheet(_ actionSheet: UIAlertController, viewModel: ItemViewModel)
    func pushItemController(forLoader loader: ItemLoader, viewModel: ItemViewModel)
}

typealias LoadModelsCompletion = (_ success: Bool, _ error: Error?) -> Void

class ItemViewModel: NSObject {
    
    // MARK: - Properties -
    
    fileprivate var loader: ItemLoader
    
    var serverId: Int64 {
        return loader.serverId
    }
    
    var isDownloadQueue: Bool {
        if let loader = loader as? CachedPlaylistLoader, loader.playlistId == Playlist.downloadQueuePlaylistId {
            return true
        }
        return false
    }
    
    var isRootItemLoader: Bool {
        return loader is RootItemLoader
    }
    
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
    
    var mediaFolderId: Int64? {
        didSet {
            if var rootItemLoader = loader as? RootItemLoader {
                rootItemLoader.mediaFolderId = mediaFolderId
            }
        }
    }
    
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
    
    // MARK - Lifecycle -
    
    init(loader: ItemLoader) {
        self.loader = loader
        self.rootItem = loader.associatedItem
        self.navigationTitle = self.rootItem?.itemName
        
        if let folder = loader.associatedItem as? Folder {
            self.songSortOrder = folder.songSortOrder
        }
    }
    
    // MARK - Loading -
    
    func loadModelsFromDatabase() -> Bool {
        let success = loader.loadModelsFromDatabase()
        if (success) {
            self.processModels()
        }
        
        return success
    }
    
    func loadModelsFromWeb(completion: LoadModelsCompletion? = nil) {
        if loader.state != .loading {
            loader.completionHandler = { success, error, loader in
                completion?(success, error)
                if success {
                    self.delegate?.loadingFinished(viewModel: self)
                    
                    // May have some false positives, but prevents UI pauses
                    if self.items.count != self.loader.items.count {
                        self.processModels()
                        self.delegate?.itemsChanged(viewModel: self)
                    }
                } else {
                    let errorString = error == nil ? "Unknown error" : error!.localizedDescription
                    self.delegate?.loadingError(errorString, viewModel: self)
                }
            }
            
            loader.start()
        }
    }
    
    func cancelLoad() {
        loader.cancel()
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
    
    // MARK - Actions -
    
    func playSong(atIndex index: Int) {
        // TODO: Implement a way to just switch play index when we're playing from the same array to save time
        PlayQueue.si.playSongs(songs, playIndex: index)
    }
    
    func sort(by sortOrder: SongSortOrder) {
        self.songSortOrder = sortOrder
        // TODO: How can I assign to a constant here? It's not an Obj-C object...
        if let folder = loader.associatedItem as? Folder {
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
        delegate?.itemsChanged(viewModel: self)
    }
    
    // MARK: - Action Sheets -
    
    func addCancelAction(toActionSheet actionSheet: UIAlertController) {
        actionSheet.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
    }
    
    // MARK: Cell
    
    func cellActionSheet(forItem item: Item, indexPath: IndexPath) -> UIAlertController {
        let alertController = UIAlertController(title: item.itemName, message: nil, preferredStyle: .actionSheet)
        return alertController
    }
    
    func addPlayQueueActions(toActionSheet actionSheet: UIAlertController, forItem item: Item, indexPath: IndexPath) {
        actionSheet.addAction(UIAlertAction(title: "Play All", style: .default) { action in
            if item is Song {
                self.playSong(atIndex: indexPath.row)
            } else {
                let loader = RecursiveSongLoader(item: item)
                loader.completionHandler = { success, _, _ in
                    if success {
                        PlayQueue.si.playSongs(loader.songs, playIndex: 0)
                    }
                }
                loader.start()
            }
        })
        
        actionSheet.addAction(UIAlertAction(title: "Queue Next", style: .default) { action in
            if let song = item as? Song {
                PlayQueue.si.insertSongNext(song: song, notify: true)
            } else {
                let loader = RecursiveSongLoader(item: item)
                loader.completionHandler = { success, _, _ in
                    if success {
                        for song in loader.songs.reversed() {
                            PlayQueue.si.insertSongNext(song: song, notify: false)
                        }
                        PlayQueue.si.notifyPlayQueueIndexChanged()
                    }
                }
                loader.start()
            }
        })
        
        actionSheet.addAction(UIAlertAction(title: "Queue Last", style: .default) { action in
            if let song = item as? Song {
                PlayQueue.si.insertSong(song: song, index: PlayQueue.si.songCount, notify: true)
            } else {
                let loader = RecursiveSongLoader(item: item)
                loader.completionHandler = { success, _, _ in
                    if success {
                        for song in loader.songs {
                            PlayQueue.si.insertSong(song: song, index: PlayQueue.si.songCount, notify: false)
                        }
                        PlayQueue.si.notifyPlayQueueIndexChanged()
                    }
                }
                loader.start()
            }
        })
    }
    
    func addGoToRelatedActions(toActionSheet actionSheet: UIAlertController, forItem item: Item, indexPath: IndexPath) {
        if !isBrowsingCache, let song = item as? Song {
            if !isBrowsingFolder, let folderId = song.folderId, let mediaFolderId = song.mediaFolderId {
                actionSheet.addAction(UIAlertAction(title: "Go to Folder", style: .default) { action in
                    let loader = FolderLoader(folderId: folderId, serverId: self.serverId, mediaFolderId: mediaFolderId)
                    self.delegate?.pushItemController(forLoader: loader, viewModel: self)
                })
            }
            
            if let artistId = song.artistId {
                actionSheet.addAction(UIAlertAction(title: "Go to Artist", style: .default) { action in
                    let loader = ArtistLoader(artistId: artistId, serverId: self.serverId)
                    self.delegate?.pushItemController(forLoader: loader, viewModel: self)
                })
            }
            
            if !isBrowsingAlbum, let albumId = song.albumId {
                actionSheet.addAction(UIAlertAction(title: "Go to Album", style: .default) { action in
                    let loader = AlbumLoader(albumId: albumId, serverId: self.serverId)
                    self.delegate?.pushItemController(forLoader: loader, viewModel: self)
                })
            }
        }
    }
    
    // MARK: View Options
    
    func viewOptionsActionSheet() -> UIAlertController {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        
        
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        
        return alertController
    }
    
    func addSortOptions(toActionSheet actionSheet: UIAlertController) {
        if songs.count > 0 {
            actionSheet.addAction(UIAlertAction(title: "Sort By Track Number", style: .default) { action in
                self.sort(by: .track)
            })
            actionSheet.addAction(UIAlertAction(title: "Sort By Song Title", style: .default) { action in
                self.sort(by: .title)
            })
            actionSheet.addAction(UIAlertAction(title: "Sort By Artist", style: .default) { action in
                self.sort(by: .artist)
            })
            actionSheet.addAction(UIAlertAction(title: "Sort By Album", style: .default) { action in
                self.sort(by: .album)
            })
        }
    }
    
    func addDisplayOptions(toActionSheet actionSheet: UIAlertController) {
        if songs.count > 0 {
            let trackNumbersTitle = self.isShowTrackNumbers ? "Hide Track Numbers" : "Show Track Numbers"
            actionSheet.addAction(UIAlertAction(title: trackNumbersTitle, style: .default) { action in
                self.isShowTrackNumbers = !self.isShowTrackNumbers
                self.delegate?.itemsChanged(viewModel: self)
            })
        }
    }
}
