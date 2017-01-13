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
    
    fileprivate let singleTapRecognizer = UITapGestureRecognizer()
    fileprivate let doubleTapRecognizer = UITapGestureRecognizer()
    
    fileprivate let viewModel: ItemViewModel
    fileprivate var reloading: Bool = false
    
    init(viewModel: ItemViewModel) {
        self.viewModel = viewModel
        super.init(nibName: nil, bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override var preferredStatusBarStyle : UIStatusBarStyle {
        return .lightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge()
        self.automaticallyAdjustsScrollViewInsets = false
        
        viewModel.delegate = self
        _ = viewModel.loadModelsFromDatabase()
        viewModel.loadModelsFromWeb(nil)
        
        self.navigationItem.title = viewModel.navigationTitle
        self.tableView.tableFooterView = UIView(frame:CGRect(x: 0, y: 0, width: 320, height: 64))
    }
    
    override func customizeTableView(_ tableView: UITableView) {
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
    
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
        
        registerForNotifications()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        unregisterForNotifications()
    }
    
    deinit {
        viewModel.cancelLoad()
        
        unregisterForNotifications()
    }
    
    override func setupLeftBarButton() -> UIBarButtonItem {
        if viewModel.topLevelController {
            return UIBarButtonItem(title: "Menu", style: .plain, target: self, action: #selector(showMenu))
        } else {
            return super.setupLeftBarButton()
        }
    }
    
    override func setupRightBarButton() -> UIBarButtonItem {
        if viewModel.isBrowsingFolder && viewModel.songs.count > 0 {
            return UIBarButtonItem(title: "•••", style: .plain, target: self, action: #selector(showOptions))
        } else {
            return super.setupRightBarButton()
        }
    }
    
    @objc fileprivate func showOptions() {
        let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
        alertController.addAction(UIAlertAction(title: "Alphabetize Songs", style: .default) { action in
            self.viewModel.alphabetizeSongs()
        })
        let trackNumbersTitle = self.viewModel.isShowTrackNumbers ? "Hide Track Numbers" : "Show Track Numbers"
        alertController.addAction(UIAlertAction(title: trackNumbersTitle, style: .default) { action in
            self.viewModel.isShowTrackNumbers = !self.viewModel.isShowTrackNumbers
            self.tableView.reloadData()
        })
        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        self.present(alertController, animated: true, completion: nil)
    }
    
    // MARK: - Notifications -
    
    fileprivate func registerForNotifications() {
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(currentPlaylistIndexChanged(_:)), name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(songPlaybackStarted(_:)), name: ISMSNotification_SongPlaybackStarted, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(cachedSongDeleted(_:)), name: ISMSNotification_CachedSongDeleted, object: nil)
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(draggingBegan(_:)), name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(draggingEnded(_:)), name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(draggingCanceled(_:)), name: DraggableTableView.Notifications.draggingCanceled, object: nil)
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(forceTouchDetectionBegan(_:)), name: DraggableTableView.Notifications.forceTouchDetectionBegan, object: nil)
    }
    
    fileprivate func unregisterForNotifications() {
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_SongPlaybackStarted, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: ISMSNotification_CachedSongDeleted, object: nil)
        
        NotificationCenter.removeObserver(onMainThread: self, name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NotificationCenter.removeObserver(onMainThread: self, name: DraggableTableView.Notifications.draggingCanceled, object: nil)
        
        NotificationCenter.removeObserver(onMainThread: self, name: DraggableTableView.Notifications.forceTouchDetectionBegan, object: nil)
    }
    
    @objc fileprivate func currentPlaylistIndexChanged(_ notification: Notification?) {
        self.tableView.reloadData()
    }
    
    @objc fileprivate func songPlaybackStarted(_ notification: Notification?) {
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
            viewModel.loadModelsFromWeb(nil)
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
    
    // MARK: - Table View Delegate -
    
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
            cell.associatedObject = folder
            cell.coverArtId = folder.coverArtId
            cell.title = folder.name
        case artistsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.alwaysShowCoverArt = true
            
            let artist = viewModel.artists[indexPath.row]
            cell.associatedObject = artist
            cell.coverArtId = artist.coverArtId
            cell.title = artist.name
        case albumsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.disclosureIndicator
            cell.alwaysShowCoverArt = true
            
            let album = viewModel.albums[indexPath.row]
            cell.associatedObject = album
            cell.coverArtId = album.coverArtId
            cell.title = album.name
        case songsSectionIndex:
            cell.selectionStyle = .none
            cell.accessoryType = UITableViewCellAccessoryType.none
            cell.alwaysShowSubtitle = true
            
            let song = viewModel.songs[indexPath.row]
            cell.associatedObject = song
            cell.coverArtId = nil
            cell.title = song.title
            cell.trackNumber = viewModel.isShowTrackNumbers ? song.trackNumber : nil
            cell.subTitle = song.artistDisplayName
            cell.duration = song.duration
            cell.isPlaying = (song == PlayQueue.si.currentDisplaySong)
        default:
            break
        }
        
        return cell
    }
    
    override func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        var height: CGFloat = 0
        
        switch indexPath.section {
        case foldersSectionIndex:
            height = ISMSSubfolderCellHeight
        case artistsSectionIndex:
            height = ISMSArtistCellHeight
        case albumsSectionIndex:
            height = ISMSAlbumCellHeight
        case songsSectionIndex:
            height = ISMSSongCellHeight
        default:
            break
        }
        
        return ISMSNormalize(height)
    }
    
    @objc fileprivate func singleTap(_ recognizer: UITapGestureRecognizer) {
        if recognizer.state == .ended {
            let point = recognizer.location(in: self.tableView)
            guard let indexPath = self.tableView.indexPathForRow(at: point) else {
                return
            }
            
            switch indexPath.section {
            case songsSectionIndex:
                let song = self.viewModel.songs[indexPath.row]
                showActionSheet(item: song, indexPath: indexPath)
            default:
                break
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
            default:
                break
            }
        }
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        switch indexPath.section {
        case foldersSectionIndex:
            let folder = self.viewModel.folders[indexPath.row]
            if let loader = viewModel.loaderForFolder(folder) {
                pushItemController(loader: loader)
            }
        case artistsSectionIndex:
            let artist = self.viewModel.artists[indexPath.row]
            if let loader = viewModel.loaderForArtist(artist) {
                pushItemController(loader: loader)
            }
        case albumsSectionIndex:
            let album = self.viewModel.albums[indexPath.row]
            if let loader = viewModel.loaderForAlbum(album) {
                pushItemController(loader: loader)
            }
        default:
            tableView.deselectRow(at: indexPath, animated: false)
        }
    }
    
    fileprivate func showActionSheet(item: ISMSItem, indexPath: IndexPath) {
        if let song = item as? ISMSSong {
            let alertController = UIAlertController(title: nil, message: nil, preferredStyle: .actionSheet)
            
            alertController.addAction(UIAlertAction(title: "Play All", style: .default) { action in
                self.viewModel.playSong(atIndex: indexPath.row)
            })
            
            alertController.addAction(UIAlertAction(title: "Queue Next", style: .default) { action in
                PlayQueue.si.insertSongNext(song: song, notify: true)
            })
            
            alertController.addAction(UIAlertAction(title: "Queue Last", style: .default) { action in
                PlayQueue.si.insertSong(song: song, index: PlayQueue.si.songCount, notify: true)
            })
            
            if !viewModel.isBrowsingFolder, let folderId = song.folderId as? Int, let mediaFolderId = song.mediaFolderId as? Int {
                alertController.addAction(UIAlertAction(title: "Go to Folder", style: .default) { action in
                    let loader = FolderLoader(folderId: folderId, mediaFolderId: mediaFolderId)
                    self.pushItemController(loader: loader)
                })
            }
            
            if let artistId = song.artistId as? Int {
                alertController.addAction(UIAlertAction(title: "Go to Artist", style: .default) { action in
                    let loader = ArtistLoader(artistId: artistId)
                    self.pushItemController(loader: loader)
                })
            }
            
            if !viewModel.isBrowsingAlbum, let albumId = song.albumId as? Int {
                alertController.addAction(UIAlertAction(title: "Go to Album", style: .default) { action in
                    let loader = AlbumLoader(albumId: albumId)
                    self.pushItemController(loader: loader)
                })
            }
            
            if viewModel.isBrowsingCache {
                alertController.addAction(UIAlertAction(title: "Remove", style: .destructive) { action in
                    song.removeFromCache()
                })
            }
            
            alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
            
            self.present(alertController, animated: true, completion: nil)
        }
    }
    
    fileprivate func pushItemController(loader: ItemLoader) {
        let viewModel = ItemViewModel(loader: loader)
        let viewController = ItemViewController(viewModel: viewModel)
        self.navigationController?.pushViewController(viewController, animated: true)
    }
}

extension ItemViewController : ItemViewModelDelegate {
    
    func itemsChanged() {
        self.tableView.reloadData()        
    }
    
    func loadingFinished() {
        dataSourceDidFinishLoadingNewData()
    }
    
    func loadingError(_ error: String) {
        let message = "There was an error loading the folder.\n\nError \(error)"
        
        let alert = UIAlertController(title: "Error", message: message, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default, handler: nil))
        self.present(alert, animated: true, completion: nil)
        
        LoadingScreen.hide()
        
        dataSourceDidFinishLoadingNewData()
    }
}
