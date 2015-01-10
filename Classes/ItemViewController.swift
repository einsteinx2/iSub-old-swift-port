//
//  ItemViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class ItemViewController: CustomUITableViewController, ISMSLoaderDelegate, CustomUITableViewCellDelegate {
    
    private let _appDelegate = iSubAppDelegate.sharedInstance()
    private let _viewObjects = ViewObjectsSingleton.sharedInstance()
    private let _database = DatabaseSingleton.sharedInstance()
    
    private let _reuseIdentifier = "Custom Cell"
    
    private let _itemLoader: ISMSItemLoader
    private var _reloading: Bool = false
    // TODO: Use tuples after porting the data model
    private var _sectionIndexes: [ISMSSectionIndex]?
    
    private let _hasCachedItems: Bool
    
    @IBOutlet public var playAllShuffleAllView: UIView?
    @IBOutlet public var albumInfoView: UIView?
    @IBOutlet public var albumInfoArtHolderView: UIView?
    @IBOutlet public var albumInfoArtView: AsynchronousImageView?
    @IBOutlet public var albumInfoLabelHolderView: UIView?
    @IBOutlet public var albumInfoArtistLabel: UILabel?
    @IBOutlet public var albumInfoAlbumLabel: UILabel?
    @IBOutlet public var albumInfoTrackCountLabel: UILabel?
    @IBOutlet public var albumInfoDurationLabel: UILabel?
    
    public init(itemLoader: ISMSItemLoader) {
        _hasCachedItems = itemLoader.loadModelsFromCache()
        _itemLoader = itemLoader
        
        super.init(nibName: "ItemViewController", bundle: nil)
        
        _itemLoader.delegate = self
        if !_hasCachedItems {
            _itemLoader.startLoad()
        }
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge.None
        self.automaticallyAdjustsScrollViewInsets = false
        
        albumInfoArtView?.delegate = self
        
        if _hasCachedItems {
            _addHeaderAndIndex()
        }
    }
    
    public override func customizeTableView(tableView: UITableView!) {
        tableView.registerClass(CustomUITableViewCell.self, forCellReuseIdentifier: _reuseIdentifier)
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
        
        _registerForNotifications()
    }
    
    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        _itemLoader.cancelLoad()
        
        _unregisterForNotifications()
    }
    
    deinit {
        _unregisterForNotifications()
    }
    
    // MARK: - Notifications - 
    
    private func _registerForNotifications() {
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "currentPlaylistIndexChanged:", name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "songPlaybackStarted:", name: ISMSNotification_SongPlaybackStarted, object: nil)
    }
    
    private func _unregisterForNotifications() {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ISMSNotification_CurrentPlaylistIndexChanged, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ISMSNotification_SongPlaybackStarted, object: nil)
    }
    
    public func currentPlaylistIndexChanged(notification: NSNotification?) {
        self.tableView.reloadData()
    }
    
    public func songPlaybackStarted(notification: NSNotification?) {
        self.tableView.reloadData()
    }
    
    // MARK: - Loading -
    
    public override func shouldSetupRefreshControl() -> Bool {
        return true
    }
    
    public override func didPullToRefresh() {
        if !_reloading {
            _reloading = true
            _viewObjects.showAlbumLoadingScreen(self.view, sender:self)
            _itemLoader.startLoad()
        }
    }
    
    private func _dataSourceDidFinishLoadingNewData() {
        _reloading = false
        self.refreshControl?.endRefreshing()
    }
    
    public func cancelLoad() {
        _itemLoader.cancelLoad()
        self._dataSourceDidFinishLoadingNewData()
        _viewObjects.hideLoadingScreen()
    }
    
    private func _addHeaderAndIndex() {
        let songsCount = _itemLoader.songs.count
        let foldersCount = _itemLoader.folders.count
        
        if songsCount == 0 && foldersCount == 0 {
            self.tableView.tableHeaderView = nil;
        } else if songsCount > 0 {
            if self.tableView.tableHeaderView == nil {
                let headerHeight = albumInfoView!.height + playAllShuffleAllView!.height
                let headerFrame = CGRectMake(0, 0, 320, headerHeight)
                let headerView = UIView(frame: headerFrame)
                
                albumInfoArtView!.isLarge = true
                
                headerView.addSubview(albumInfoView!)
                
                playAllShuffleAllView!.y = albumInfoView!.height
                headerView.addSubview(playAllShuffleAllView!)
                
                self.tableView.tableHeaderView = headerView
            }
            
            switch _itemLoader.associatedObject {
            case let folder as ISMSFolder:
                albumInfoArtView!.coverArtId = folder.coverArtId?.stringValue
                albumInfoArtistLabel!.text = folder.name
                //albumInfoAlbumLabel!.text = _album!.title
            default:
                break
            }

//            albumInfoDurationLabel!.text = NSString.formatTime(Double(_dataModel.folderLength))
//            albumInfoTrackCountLabel!.text = "\(_dataModel.songsCount) Tracks"
//            if _dataModel.songsCount == 1 {
//                albumInfoTrackCountLabel!.text = "\(_dataModel.songsCount) Track"
//            }
            
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
        } else {
            self.tableView.tableHeaderView = playAllShuffleAllView
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
        }
        
        if foldersCount > 20 && songsCount == 0 {
            _sectionIndexes = sectionIndexesForItems(_itemLoader.songs as [ISMSSong])
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Actions -
    
    @IBAction public func a_expandCoverArt(sender: AnyObject?) {
        var modalArtViewController: ModalAlbumArtViewController?
        
        switch _itemLoader.associatedObject {
        case let folder as ISMSFolder:
            modalArtViewController = ModalAlbumArtViewController(title: folder.name, subtitle: nil, coverArtId: folder.coverArtId?.stringValue, numberOfTracks: _itemLoader.songs!.count, albumLength: 0)
        default:
            break
        }
        
        if let controller = modalArtViewController? {
            if IS_IPAD() {
                _appDelegate.ipadRootViewController.presentViewController(controller, animated: true, completion: nil)
            } else {
                self.presentViewController(controller, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction public func a_playAll(sender: AnyObject?) {
        playAll(songs: _itemLoader.songs as [ISMSSong], playIndex: 0)
    }
    
    @IBAction public func a_shuffle(sender: AnyObject?) {
        shuffleAll(songs: _itemLoader.songs as [ISMSSong], playIndex: 0)
    }
    
    // MARK: - Table View Delegate -
    
    public override func sectionIndexTitlesForTableView(tableView: UITableView) -> [AnyObject]! {
        var titles: [String] = []
        
        if let sectionIndexes = _sectionIndexes {
            for sectionIndex in sectionIndexes {
                titles.append(String(sectionIndex.letter))
            }
        }
        
        return titles;
    }
    
    public override func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        if let sectionIndexes = _sectionIndexes? {
            let sectionIndex = sectionIndexes[index]
            let indexPath = NSIndexPath(forRow: sectionIndex.firstIndex, inSection: 0)
            tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Top, animated: false)
        }
        
        return -1;
    }
    
    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 2
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if section == 0 {
            return _itemLoader.folders.count
        } else {
            return _itemLoader.songs.count
        }
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(_reuseIdentifier, forIndexPath: indexPath) as CustomUITableViewCell
        cell.alwaysShowSubtitle = true
        cell.delegate = self
        
        if indexPath.section == 0 {
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.alwaysShowCoverArt = true
            
            let folder = _itemLoader.folders[indexPath.row] as ISMSFolder
            
            if _sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            cell.associatedObject = folder
            cell.coverArtId = folder.coverArtId?.stringValue
            cell.title = folder.name
            
            return cell;
        } else {
            cell.accessoryType = UITableViewCellAccessoryType.None
            
            let song = _itemLoader.songs[indexPath.row] as ISMSSong
            
            cell.indexPath = indexPath
            cell.associatedObject = song
            cell.trackNumber = song.track
            cell.title = song.title
            cell.subTitle = song.artistName == nil ? "" : song.artistName
            cell.duration = song.duration
            cell.playing = song.isCurrentPlayingSong()
            
            if song.isFullyCached {
                cell.backgroundView = UIView()
                cell.backgroundView!.backgroundColor = _viewObjects.currentLightColor()
            } else {
                cell.backgroundView = _viewObjects.createCellBackground(indexPath.row)
            }
            
            return cell
        }
    }
    
    public override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        let height = indexPath.section == 0 ? ISMSAlbumCellHeight : ISMSSongCellHeight
        return ISMSNormalize(height)
    }
    
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if _viewObjects.isCellEnabled {
            if indexPath.section == 0 {
                let folder = _itemLoader.folders[indexPath.row] as ISMSFolder
                let folderLoader = ISMSFolderLoader()
                folderLoader.folderId = folder.folderId
                folderLoader.mediaFolderId = folder.mediaFolderId
                
                let itemViewController = ItemViewController(itemLoader: folderLoader)
                self.pushViewControllerCustom(itemViewController)
            } else {
                // TODO: Implement a way to just switch play index when we're playing from the same array to save time
                playAll(songs: _itemLoader.songs as [ISMSSong], playIndex: indexPath.row)
                
                let song = _itemLoader.songs[indexPath.row] as ISMSSong
                if !song.isVideo {
                    self.showPlayer()
                }
            }
        }
        else
        {
            self.tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
    
    // MARK: - ISMSLoader Delegate -
    
    public func loadingFailed(theLoader: ISMSLoader!, withError error: NSError!) {
        let message = "There was an error loading the folder.\n\nError \(error?.code): \(error?.localizedDescription)"
        
        let alert = CustomUIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
        
        _viewObjects.hideLoadingScreen()
        
        _dataSourceDidFinishLoadingNewData()
    }
    
    public func loadingFinished(theLoader: ISMSLoader!) {
        _itemLoader.persistModels()
        
        _viewObjects.hideLoadingScreen()
        
        self.tableView.reloadData()
        _addHeaderAndIndex()
        
        _dataSourceDidFinishLoadingNewData()
    }
    
    // MARK: - CustomUITableViewCell Delegate -

    public func tableCellDownloadButtonPressed(cell: CustomUITableViewCell) {
        switch cell.associatedObject {
            case let song as ISMSSong:
                song.addToCacheQueueDbQueue()
            case let album as ISMSAlbum:
                let artist = ISMSArtist(name: album.artistName, andArtistId: album.artistId)
                _database.downloadAllSongs(album.albumId, artist: artist)
            default:
                break;
        }
        
        cell.overlayView?.disableDownloadButton()
    }
    
    public func tableCellQueueButtonPressed(cell: CustomUITableViewCell) {
        switch cell.associatedObject {
            case let song as ISMSSong:
                song.addToCurrentPlaylistDbQueue()
                NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_CurrentPlaylistSongsQueued)
            case let album as ISMSAlbum:
                let artist = ISMSArtist(name: album.artistName, andArtistId: album.artistId)
                _database.queueAllSongs(album.albumId, artist: artist)
            default:
                break;
        }
    }
}
