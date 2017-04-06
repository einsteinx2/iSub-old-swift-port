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
    func pushViewController(_ viewController: UIViewController, viewModel: ItemViewModel)
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
    
    var isTopLevelController: Bool {
        return false
    }
    
    fileprivate(set) var artistSortOrder = ArtistSortOrder.name
    fileprivate(set) var albumSortOrder = AlbumSortOrder.year
    fileprivate(set) var songSortOrder = SongSortOrder.track
    var isShowTrackNumbers = true
    
    var delegate: ItemViewModelDelegate?
    
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
    
    init(loader: ItemLoader, title: String? = nil) {
        self.loader = loader
        self.rootItem = loader.associatedItem
        self.navigationTitle = title //?? loader.associatedItem?.itemName
        
        if let folder = loader.associatedItem as? Folder {
            self.songSortOrder = folder.songSortOrder
        } else if let artist = loader.associatedItem as? Artist {
            self.albumSortOrder = artist.albumSortOrder
        } else if let album = loader.associatedItem as? Album {
            self.songSortOrder = album.songSortOrder
        } else if loader is RootItemLoader {
            // TODO: Re-enable this after figuring out the weird crash
            //self.artistSortOrder = SavedSettings.si.rootArtistSortOrder
            //self.albumSortOrder = SavedSettings.si.rootAlbumSortOrder
        }
    }
    
    // MARK - Loading -
    
    @discardableResult func loadModelsFromDatabase() -> Bool {
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
            case let item as Folder:   folders.append(item)
            case let item as Artist:   artists.append(item)
            case let item as Album:    albums.append(item)
            case let item as Song:     songs.append(item)
            case let item as Playlist: playlists.append(item)
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
        
        sortAll()
    }
    
    fileprivate func createSectionIndexes() {
        let minAmountForIndexes = 50
        if folders.count >= minAmountForIndexes {
            sectionIndexes = SectionIndex.sectionIndexes(forItems: folders)
            sectionIndexesSection = 0
        } else if artists.count >= minAmountForIndexes {
            if artistSortOrder == .name {
                sectionIndexes = SectionIndex.sectionIndexes(forItems: artists)
            } else {
                sectionIndexes = SectionIndex.sectionIndexes(forCount: artists.count)
            }
            sectionIndexesSection = 1
        } else if albums.count >= minAmountForIndexes {
            if albumSortOrder == .name {
                sectionIndexes = SectionIndex.sectionIndexes(forItems: albums)
            } else {
                sectionIndexes = SectionIndex.sectionIndexes(forCount: albums.count)
            }
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
                sectionIndexes = SectionIndex.sectionIndexes(forCount: songs.count)
            }
            sectionIndexesSection = 3
        } else {
            sectionIndexes = []
            sectionIndexesSection = -1
        }
    }
    
    // MARK - Actions -
    
    func playSong(atIndex index: Int) {
        PlayQueue.si.playSongs(songs, playIndex: index)
    }
    
    func sortAll() {
        var sorted = false
        sorted = sorted || sortArtists(by: artistSortOrder, createIndexes: false, notify: false)
        sorted = sorted || sortAlbums(by: albumSortOrder, createIndexes: false, notify: false)
        sorted = sorted || sortSongs(by: songSortOrder, createIndexes: false, notify: false)
        
        if sorted {
            createSectionIndexes()
            delegate?.itemsChanged(viewModel: self)
        }
    }
    
    @discardableResult func sortArtists(by sortOrder: ArtistSortOrder, createIndexes: Bool = true, notify: Bool = true) -> Bool {
        artistSortOrder = sortOrder
        SavedSettings.si.rootArtistSortOrder = sortOrder
        
        guard artists.count > 0 else {
            return false
        }
        
        artists.sort { lhs, rhs -> Bool in
            switch sortOrder {
            case .name: return lhs.name.lowercased() < rhs.name.lowercased()
            case .albumCount: return lhs.albumCount ?? 0 < rhs.albumCount ?? 0
            }
        }
        
        if createIndexes {
            createSectionIndexes()
        }
        
        if notify {
            delegate?.itemsChanged(viewModel: self)
        }
        
        return true
    }
    
    @discardableResult func sortAlbums(by sortOrder: AlbumSortOrder, createIndexes: Bool = true, notify: Bool = true) -> Bool {
        self.albumSortOrder = sortOrder
        if isRootItemLoader {
            SavedSettings.si.rootAlbumSortOrder = sortOrder
        } else if let artist = loader.associatedItem as? Artist {
            artist.albumSortOrder = sortOrder
            artist.replace()
        }
        
        guard albums.count > 0 else {
            return false
        }
        
        albums.sort { lhs, rhs -> Bool in
            switch sortOrder {
            case .year: return lhs.year ?? 0 < rhs.year ?? 0
            case .name: return lhs.name.lowercased() < rhs.name.lowercased()
            case .artist: return lhs.artist?.name ?? "" < rhs.artist?.name ?? ""
            case .genre: return lhs.genre?.name ?? "" < rhs.genre?.name ?? ""
            case .songCount: return lhs.songCount ?? 0 < rhs.songCount ?? 0
            case .duration: return lhs.duration ?? 0 < rhs.duration ?? 0
            }
        }
        
        if createIndexes {
            createSectionIndexes()
        }
        
        if notify {
            delegate?.itemsChanged(viewModel: self)
        }
        
        return true
    }
    
    @discardableResult func sortSongs(by sortOrder: SongSortOrder, createIndexes: Bool = true, notify: Bool = true) -> Bool {
        self.songSortOrder = sortOrder
        if let folder = loader.associatedItem as? Folder {
            folder.songSortOrder = sortOrder
            folder.replace()
        } else if let album = loader.associatedItem as? Album {
            album.songSortOrder = sortOrder
            album.replace()
        }
        
        guard songs.count > 0 else {
            return false
        }
        
        songs.sort { lhs, rhs -> Bool in
            switch sortOrder {
            case .track: return lhs.trackNumber ?? 0 < rhs.trackNumber ?? 0
            case .title: return lhs.title.lowercased() < rhs.title.lowercased()
            case .artist: return lhs.artistDisplayName?.lowercased() ?? "" < rhs.artistDisplayName?.lowercased() ?? ""
            case .album: return lhs.albumDisplayName?.lowercased() ?? "" < rhs.albumDisplayName?.lowercased() ?? ""
            }
        }
        
        if createIndexes {
            createSectionIndexes()
        }
        
        if notify {
            delegate?.itemsChanged(viewModel: self)
        }
        
        return true
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
                    if let controller = itemViewController(forLoader: loader) {
                        self.delegate?.pushViewController(controller, viewModel: self)
                    }
                })
            }
            
            if let artistId = song.artistId {
                actionSheet.addAction(UIAlertAction(title: "Go to Artist", style: .default) { action in
                    let loader = ArtistLoader(artistId: artistId, serverId: self.serverId)
                    if let controller = itemViewController(forLoader: loader) {
                        self.delegate?.pushViewController(controller, viewModel: self)
                    }
                })
            }
            
            if !isBrowsingAlbum, let albumId = song.albumId {
                actionSheet.addAction(UIAlertAction(title: "Go to Album", style: .default) { action in
                    let loader = AlbumLoader(albumId: albumId, serverId: self.serverId)
                    if let controller = itemViewController(forLoader: loader) {
                        self.delegate?.pushViewController(controller, viewModel: self)
                    }
                })
            }
        }
    }
    
    // MARK: View Options
    
    func viewOptionsActionSheet() -> UIAlertController {
        return UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
    }
    
    func addSortOptions(toActionSheet actionSheet: UIAlertController) {
        if artists.count > 1 {
            actionSheet.addAction(UIAlertAction(title: "Sort Artists", style: .default) { action in
                self.delegate?.presentActionSheet(self.sortArtistsActionsSheet(), viewModel: self)
            })
        }
        
        if albums.count > 1 {
            actionSheet.addAction(UIAlertAction(title: "Sort Albums", style: .default) { action in
                self.delegate?.presentActionSheet(self.sortAlbumsActionsSheet(), viewModel: self)
            })
        }
        
        if songs.count > 1 {
            actionSheet.addAction(UIAlertAction(title: "Sort Songs", style: .default) { action in
                self.delegate?.presentActionSheet(self.sortSongsActionsSheet(), viewModel: self)
            })
        }
    }
    
    func sortArtistsActionsSheet() -> UIAlertController {
        let actionSheet = UIAlertController(title: "Sort Artists By:", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Name", style: .default) { action in
            self.sortArtists(by: .name)
        })
        actionSheet.addAction(UIAlertAction(title: "Album Count", style: .default) { action in
            self.sortArtists(by: .albumCount)
        })
        return actionSheet
    }
    
    func sortAlbumsActionsSheet() -> UIAlertController {
        let actionSheet = UIAlertController(title: "Sort Albums By:", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Year", style: .default) { action in
            self.sortAlbums(by: .year)
        })
        actionSheet.addAction(UIAlertAction(title: "Name", style: .default) { action in
            self.sortAlbums(by: .name)
        })
        actionSheet.addAction(UIAlertAction(title: "Artist", style: .default) { action in
            self.sortAlbums(by: .artist)
        })
        actionSheet.addAction(UIAlertAction(title: "Genre", style: .default) { action in
            self.sortAlbums(by: .genre)
        })
        actionSheet.addAction(UIAlertAction(title: "Song Count", style: .default) { action in
            self.sortAlbums(by: .songCount)
        })
        actionSheet.addAction(UIAlertAction(title: "Duration", style: .default) { action in
            self.sortAlbums(by: .duration)
        })
        return actionSheet
    }
    
    func sortSongsActionsSheet() -> UIAlertController {
        let actionSheet = UIAlertController(title: "Sort Songs By:", message: nil, preferredStyle: .actionSheet)
        actionSheet.addAction(UIAlertAction(title: "Track Number", style: .default) { action in
            self.sortSongs(by: .track)
        })
        actionSheet.addAction(UIAlertAction(title: "Title", style: .default) { action in
            self.sortSongs(by: .title)
        })
        actionSheet.addAction(UIAlertAction(title: "Artist", style: .default) { action in
            self.sortSongs(by: .artist)
        })
        actionSheet.addAction(UIAlertAction(title: "Album", style: .default) { action in
            self.sortSongs(by: .album)
        })
        return actionSheet
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
