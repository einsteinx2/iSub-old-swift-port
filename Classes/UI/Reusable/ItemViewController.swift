//
//  ItemViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

class ItemViewController: DraggableTableViewController {
    
    // MARK: - Constants -
    
    fileprivate let folderCellIdentifier = "Folder Cell"
    fileprivate let artistCellIdentifier = "Artist Cell"
    fileprivate let albumCellIdentifier = "Album Cell"
    fileprivate let songCellIdentifier = "Song Cell"
    fileprivate let playlistCellIdentifier = "Playlist Cell"
    
    fileprivate let foldersSectionIndex   = 0
    fileprivate let artistsSectionIndex   = 1
    fileprivate let albumsSectionIndex    = 2
    fileprivate let songsSectionIndex     = 3
    fileprivate let playlistsSectionIndex = 4
    
    // MARK: - Properties -
    
    fileprivate let singleTapRecognizer = UITapGestureRecognizer()
    fileprivate let doubleTapRecognizer = UITapGestureRecognizer()
    
    fileprivate let viewModel: ItemViewModel
    fileprivate var reloading: Bool = false
    
    // MARK - Lifecycle -
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    init(viewModel: ItemViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    deinit {
        viewModel.cancelLoad()
        unregisterForNotifications()
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge()
        self.automaticallyAdjustsScrollViewInsets = false
        
        viewModel.delegate = self
        _ = viewModel.loadModelsFromDatabase()
        viewModel.loadModelsFromWeb()
        
        self.navigationItem.title = viewModel.navigationTitle
        self.tableView.tableFooterView = UIView(frame:CGRect(x: 0, y: 0, width: 320, height: 64))
    }
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
        
        registerForNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        unregisterForNotifications()
    }
    
    override func setupLeftBarButton() -> UIBarButtonItem {
        if viewModel.isTopLevelController {
            return UIBarButtonItem(title: "Menu", style: .plain, target: self, action: #selector(showMenu))
        } else {
            return super.setupLeftBarButton()
        }
    }
    
    override func setupRightBarButton() -> UIBarButtonItem {
        return UIBarButtonItem(title: "•••", style: .plain, target: self, action: #selector(showOptions))
    }
    
    @objc fileprivate func showOptions() {
        let actionSheet = viewModel.viewOptionsActionSheet()
        viewModel.addCancelAction(toActionSheet: actionSheet)
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    // MARK: - Notifications -
    
    fileprivate func registerForNotifications() {
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(currentPlaylistIndexChanged(_:)), name: PlayQueue.Notifications.indexChanged)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songPlaybackStarted(_:)), name: BassGaplessPlayer.Notifications.songStarted)
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songDownloaded(_:)), name: StreamHandler.Notifications.downloaded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(songRemoved(_:)), name: CacheManager.Notifications.songRemoved)
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(draggingBegan(_:)), name: DraggableTableView.Notifications.draggingBegan)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(draggingEnded(_:)), name: DraggableTableView.Notifications.draggingEnded)
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(draggingCanceled(_:)), name: DraggableTableView.Notifications.draggingCanceled)
        
        NotificationCenter.addObserverOnMainThread(self, selector: #selector(forceTouchDetectionBegan(_:)), name: DraggableTableView.Notifications.forceTouchDetectionBegan)
    }
    
    fileprivate func unregisterForNotifications() {
        NotificationCenter.removeObserverOnMainThread(self, name: PlayQueue.Notifications.indexChanged)
        NotificationCenter.removeObserverOnMainThread(self, name: BassGaplessPlayer.Notifications.songStarted)
        
        NotificationCenter.removeObserverOnMainThread(self, name: StreamHandler.Notifications.downloaded)
        NotificationCenter.removeObserverOnMainThread(self, name: CacheManager.Notifications.songRemoved)
        
        NotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingBegan)
        NotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingEnded)
        NotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.draggingCanceled)
        
        NotificationCenter.removeObserverOnMainThread(self, name: DraggableTableView.Notifications.forceTouchDetectionBegan)
    }
    
    @objc fileprivate func currentPlaylistIndexChanged(_ notification: Notification?) {
        self.tableView.reloadData()
    }
    
    @objc fileprivate func songPlaybackStarted(_ notification: Notification?) {
        self.tableView.reloadData()
    }
    
    @objc fileprivate func songDownloaded(_ notification: Notification?) {
        if viewModel.isDownloadQueue {
            _ = viewModel.loadModelsFromDatabase()
        }
        self.tableView.reloadData()
    }
    
    @objc fileprivate func songRemoved(_ notification: Notification?) {
        self.tableView.reloadData()
    }
    
    @objc fileprivate func cachedSongDeleted(_ notification: Notification?) {
        // Prevent tons of reloads if we delete many songs
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(cachedSongDeletedRateLimited), object: nil)
        self.perform(#selector(cachedSongDeletedRateLimited), with: nil, afterDelay: 0.25)
    }
    
    @objc fileprivate func cachedSongDeletedRateLimited() {
        if viewModel.isBrowsingCache {
            _ = viewModel.loadModelsFromDatabase()
        }
        self.tableView.reloadData()
    }
    
    @objc fileprivate func draggingBegan(_ notification: Notification) {
        singleTapRecognizer.isEnabled = false
        doubleTapRecognizer.isEnabled = false
    }
    
    @objc fileprivate func draggingEnded(_ notification: Notification) {
        singleTapRecognizer.isEnabled = true
        doubleTapRecognizer.isEnabled = true
    }
    
    @objc fileprivate func draggingCanceled(_ notification: Notification) {
        singleTapRecognizer.isEnabled = true
        doubleTapRecognizer.isEnabled = true
    }
    
    @objc fileprivate func forceTouchDetectionBegan(_ notification: Notification) {
        singleTapRecognizer.isEnabled = false
        doubleTapRecognizer.isEnabled = false
    }
    
    // MARK: - Loading -
    
    override func shouldSetupRefreshControl() -> Bool {
        return viewModel.shouldSetupRefreshControl
    }
    
    override func didPullToRefresh() {
        if !reloading {
            reloading = true
            viewModel.loadModelsFromWeb()
            
            if viewModel.isRootItemLoader {
                // Load media folders
                MediaFoldersLoader(serverId: viewModel.serverId).start()
            }
        }
    }
    
    fileprivate func dataSourceDidFinishLoadingNewData() {
        reloading = false
        self.refreshControl?.endRefreshing()
    }
    
    func cancelLoad() {
        viewModel.cancelLoad()
        dataSourceDidFinishLoadingNewData()
    }
    
    // MARK: - Table View -
    
    override func customizeTableView(_ tableView: UITableView) {
        tableView.tableHeaderView = setupHeaderView()
        
        doubleTapRecognizer.addTarget(self, action: #selector(doubleTap(_:)))
        doubleTapRecognizer.numberOfTapsRequired = 2
        doubleTapRecognizer.numberOfTouchesRequired = 1
        tableView.addGestureRecognizer(doubleTapRecognizer)
        
        singleTapRecognizer.addTarget(self, action: #selector(singleTap(_:)))
        singleTapRecognizer.numberOfTapsRequired = 1
        singleTapRecognizer.numberOfTouchesRequired = 1
        singleTapRecognizer.require(toFail: doubleTapRecognizer)
        tableView.addGestureRecognizer(singleTapRecognizer)
        
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: folderCellIdentifier)
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: artistCellIdentifier)
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: albumCellIdentifier)
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: songCellIdentifier)
        tableView.register(ItemTableViewCell.self, forCellReuseIdentifier: playlistCellIdentifier)
    }
    
    override func sectionIndexTitles(for tableView: UITableView) -> [String]? {
        return viewModel.sectionIndexes.map({$0.letter})
    }
    
    override func tableView(_ tableView: UITableView, sectionForSectionIndexTitle title: String, at index: Int) -> Int {
        if index < viewModel.sectionIndexes.count, viewModel.sectionIndexesSection >= 0 {
            let row = viewModel.sectionIndexes[index].firstIndex
            let indexPath = IndexPath(row: row, section: viewModel.sectionIndexesSection)
            tableView.scrollToRow(at: indexPath, at: UITableViewScrollPosition.top, animated: false)
        }
        
        return -1;
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 5
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count: Int? = nil
        
        switch section {
        case foldersSectionIndex:   count = viewModel.folders.count
        case artistsSectionIndex:   count = viewModel.artists.count
        case albumsSectionIndex:    count = viewModel.albums.count
        case songsSectionIndex:     count = viewModel.songs.count
        case playlistsSectionIndex: count = viewModel.playlists.count
        default: break
        }
        
        return count == nil ? 0 : count!
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        var reuseIdentifier = ""
        switch indexPath.section {
        case foldersSectionIndex:   reuseIdentifier = folderCellIdentifier
        case artistsSectionIndex:   reuseIdentifier = artistCellIdentifier
        case albumsSectionIndex:    reuseIdentifier = albumCellIdentifier
        case songsSectionIndex:     reuseIdentifier = songCellIdentifier
        case playlistsSectionIndex: reuseIdentifier = playlistCellIdentifier
        default: break
        }
        
        let cell = tableView.dequeueReusableCell(withIdentifier: reuseIdentifier, for: indexPath) as! ItemTableViewCell
        cell.cellHeight = self.tableView(tableView, heightForRowAt: indexPath)
        cell.indexShowing = (viewModel.sectionIndexes.count > 0)

        switch indexPath.section {
        case foldersSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            
            // Don't show cover art for root folders list
            if self.navigationController?.viewControllers.first != self {
                cell.alwaysShowCoverArt = true
            }
            
            let folder = viewModel.folders[indexPath.row]
            cell.associatedItem = folder
            cell.coverArtId = folder.coverArtId
            cell.title = folder.name
        case artistsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.alwaysShowCoverArt = true
            
            let artist = viewModel.artists[indexPath.row]
            cell.associatedItem = artist
            cell.coverArtId = artist.coverArtId
            cell.title = artist.name
        case albumsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.alwaysShowCoverArt = true
            
            let album = viewModel.albums[indexPath.row]
            cell.associatedItem = album
            cell.coverArtId = album.coverArtId
            cell.title = album.name
            cell.subTitle = subTitle(album: album)
        case songsSectionIndex:
            cell.selectionStyle = .none
            cell.accessoryType = UITableViewCellAccessoryType.none
            cell.alwaysShowSubtitle = true
            
            let song = viewModel.songs[indexPath.row]
            cell.associatedItem = song
            cell.coverArtId = nil
            cell.title = song.title
            cell.trackNumber = viewModel.isShowTrackNumbers ? song.trackNumber : nil
            cell.subTitle = song.artistDisplayName
            cell.duration = song.duration
            cell.isPlaying = (song == PlayQueue.si.currentDisplaySong)
        case playlistsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.alwaysShowCoverArt = true
            
            let playlist = viewModel.playlists[indexPath.row]
            cell.associatedItem = playlist
            cell.coverArtId = playlist.coverArtId
            cell.title = playlist.name
        default:
            break
        }
        
        return cell
    }
    
    fileprivate func subTitle(album: Album) -> String? {
        var subTitle = ""
        if viewModel.isRootItemLoader {
            // Main albums list, show artist name and genre first
            if let artistName = album.artist?.name {
                subTitle += "\(artistName) "
            }
            if let genreName = album.genre?.name {
                subTitle += "[\(genreName)] "
            }
        }
        
        if let year = album.year {
            subTitle += "(\(year))"
        }
        
        return subTitle.length > 0 ? subTitle : nil
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return ISMSNormalize(CellHeight)
    }
    
    @objc fileprivate func singleTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let point = recognizer.location(in: self.tableView)
            guard let indexPath = self.tableView.indexPathForRow(at: point) else {
                return
            }
            
            let isBrowsingCache = viewModel.isBrowsingCache
            
            switch indexPath.section {
            case songsSectionIndex:
                let song = self.viewModel.songs[indexPath.row]
                showCellActionSheet(item: song, indexPath: indexPath)
            case foldersSectionIndex:
                let folder = self.viewModel.folders[indexPath.row]
                if let viewController = itemViewController(forItem: folder, isBrowsingCache: isBrowsingCache) {
                    pushViewController(viewController)
                }
            case artistsSectionIndex:
                let artist = self.viewModel.artists[indexPath.row]
                if let viewController = itemViewController(forItem: artist, isBrowsingCache: isBrowsingCache) {
                    pushViewController(viewController)
                }
            case albumsSectionIndex:
                let album = self.viewModel.albums[indexPath.row]
                if let viewController = itemViewController(forItem: album, isBrowsingCache: isBrowsingCache) {
                    pushViewController(viewController)
                }
            case playlistsSectionIndex:
                let playlist = self.viewModel.playlists[indexPath.row]
                if let viewController = itemViewController(forItem: playlist, isBrowsingCache: isBrowsingCache) {
                    pushViewController(viewController)
                }
            default:
                tableView.deselectRow(at: indexPath, animated: false)
            }
        }
    }
    
    @objc fileprivate func doubleTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let point = recognizer.location(in: self.tableView)
            guard let indexPath = self.tableView.indexPathForRow(at: point) else {
                return
            }
            
            switch indexPath.section {
            case songsSectionIndex:
                viewModel.playSong(atIndex: indexPath.row)
            case foldersSectionIndex:
                let folder = self.viewModel.folders[indexPath.row]
                showCellActionSheet(item: folder, indexPath: indexPath)
            case artistsSectionIndex:
                let artist = self.viewModel.artists[indexPath.row]
                showCellActionSheet(item: artist, indexPath: indexPath)
            case albumsSectionIndex:
                let album = self.viewModel.albums[indexPath.row]
                showCellActionSheet(item: album, indexPath: indexPath)
            case playlistsSectionIndex:
                let playlist = self.viewModel.playlists[indexPath.row]
                showCellActionSheet(item: playlist, indexPath: indexPath)
            default:
                break
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if indexPath.section == songsSectionIndex {
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
    fileprivate func showCellActionSheet(item: Item, indexPath: IndexPath) {
        let actionSheet = viewModel.cellActionSheet(forItem: item, indexPath: indexPath)
        viewModel.addCancelAction(toActionSheet: actionSheet)
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    fileprivate func pushViewController(_ viewController: UIViewController) {
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

extension ItemViewController : ItemViewModelDelegate {
    
    func itemsChanged(viewModel: ItemViewModel) {
        self.tableView.reloadData()        
    }
    
    func loadingFinished(viewModel: ItemViewModel) {
        dataSourceDidFinishLoadingNewData()
    }
    
    func loadingError(_ error: String, viewModel: ItemViewModel) {
        let message = "There was an error loading the item: \(viewModel.rootItem).\n\nError \(error)"
        
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        
        LoadingScreen.hide()
        
        dataSourceDidFinishLoadingNewData()
    }
    
    func presentActionSheet(_ actionSheet: UIAlertController, viewModel: ItemViewModel) {
        self.present(actionSheet, animated: true, completion: nil)
    }
    
    func pushViewController(_ viewController: UIViewController, viewModel: ItemViewModel) {
        pushViewController(viewController)
    }
}
