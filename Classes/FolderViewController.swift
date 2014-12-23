//
//  FolderViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class FolderViewController: CustomUITableViewController, ISMSLoaderDelegate, CustomUITableViewCellDelegate {
    
    private let _appDelegate = iSubAppDelegate.sharedInstance()
    private let _viewObjects = ViewObjectsSingleton.sharedInstance()
    private let _database = DatabaseSingleton.sharedInstance()
    
    private let _reuseIdentifierAlbum = "Album Cell"
    private let _reuseIdentifierSong = "Song Cell"
    
    private let _folderId: String?
    private var _artist: ISMSArtist?
    private var _album: ISMSAlbum?
    private var _reloading: Bool = false
    // TODO: Use tuples after porting the data model
    private var _sectionInfo: [[AnyObject]]?
    private let _dataModel = SUSSubFolderDAO()
    
    @IBOutlet public var playAllShuffleAllView: UIView?
    @IBOutlet public var albumInfoView: UIView?
    @IBOutlet public var albumInfoArtHolderView: UIView?
    @IBOutlet public var albumInfoArtView: AsynchronousImageView?
    @IBOutlet public var albumInfoLabelHolderView: UIView?
    @IBOutlet public var albumInfoArtistLabel: UILabel?
    @IBOutlet public var albumInfoAlbumLabel: UILabel?
    @IBOutlet public var albumInfoTrackCountLabel: UILabel?
    @IBOutlet public var albumInfoDurationLabel: UILabel?
    
    private init(artist: ISMSArtist?, album: ISMSAlbum?)
    {
        var isArtist = false
        
        if let artist = artist? {
            isArtist = true
            _folderId = artist.artistId
            _artist = artist
            _album = nil
            
        } else if let album = album? {
            _folderId = album.albumId
            _artist = ISMSArtist(name: album.artistName, andArtistId: album.artistId)
            _album = album
            
        } else {
            fatalError("Must pass either an artist or album parameter")
        }
        
        _dataModel.myId = _folderId!
        _dataModel.myArtist = _artist!
        
        super.init(nibName: "FolderViewController", bundle: nil)
        
        self.title = isArtist ? _artist!.name : _album!.title
        
        _dataModel.delegate = self
        if (_dataModel.hasLoaded)
        {
            self.tableView.reloadData()
            _addHeaderAndIndex()
        }
        else
        {
            _viewObjects.showAlbumLoadingScreen(self.view, sender: self)
            _dataModel.startLoad()
        }
    }
    
    public convenience init(artist: ISMSArtist)
    {
        self.init(artist: artist, album: nil)
    }
    
    public convenience init(album: ISMSAlbum)
    {
        self.init(artist: nil, album: album)
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge.None
        self.automaticallyAdjustsScrollViewInsets = false
        
        albumInfoArtView?.delegate = self
    }
    
    public override func customizeTableView(tableView: UITableView!) {
        tableView.registerClass(CustomUITableViewCell.self, forCellReuseIdentifier: _reuseIdentifierAlbum)
        tableView.registerClass(CustomUITableViewCell.self, forCellReuseIdentifier: _reuseIdentifierSong)
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
        
        _registerForNotifications()
    }
    
    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        _dataModel.cancelLoad()
        
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
            _dataModel.startLoad()
        }
    }
    
    private func _dataSourceDidFinishLoadingNewData() {
        _reloading = false
        self.refreshControl?.endRefreshing()
    }
    
    public func cancelLoad() {
        _dataModel.cancelLoad()
        self._dataSourceDidFinishLoadingNewData()
        _viewObjects.hideLoadingScreen()
    }
    
    private func _addHeaderAndIndex() {
        if _dataModel.songsCount == 0 && _dataModel.albumsCount == 0 {
            self.tableView.tableHeaderView = nil;
        } else if _dataModel.songsCount > 0 {
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
            
            if _album == nil {
                let album = ISMSAlbum()
                let song = _dataModel.songForTableViewRow(_dataModel.albumsCount)
                album.title = song.album
                album.artistName = song.artist
                album.coverArtId = song.coverArtId
                _album = album
            }
            
            albumInfoArtView!.coverArtId = _album!.coverArtId
            albumInfoArtistLabel!.text = _album!.artistName
            albumInfoAlbumLabel!.text = _album!.title
            
            albumInfoDurationLabel!.text = NSString.formatTime(Double(_dataModel.folderLength))
            albumInfoTrackCountLabel!.text = "\(_dataModel.songsCount) Tracks"
            if _dataModel.songsCount == 1 {
                albumInfoTrackCountLabel!.text = "\(_dataModel.songsCount) Track"
            }
            
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
        }
        else
        {
            self.tableView.tableHeaderView = playAllShuffleAllView
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
        }
        
        _sectionInfo = _dataModel.sectionInfo() as? [[AnyObject]]
        if _sectionInfo != nil {
            self.tableView.reloadData()
        }
    }
    
    // MARK: - Actions -
    
    @IBAction public func a_expandCoverArt(sender: AnyObject?) {
        if _album?.coverArtId != nil {
            let largeArt = ModalAlbumArtViewController(album: _album!, numberOfTracks: _dataModel.songsCount, albumLength: _dataModel.folderLength)
            
            if IS_IPAD() {
                _appDelegate.ipadRootViewController.presentViewController(largeArt, animated: true, completion: nil)
            } else {
                self.presentViewController(largeArt, animated: true, completion: nil)
            }
        }
    }
    
    @IBAction public func a_playAll(sender: AnyObject?) {
        _database.playAllSongs(_folderId, artist: _artist)
    }
    
    @IBAction public func a_shuffle(sender: AnyObject?) {
        _database.shuffleAllSongs(_folderId, artist:_artist)
    }
    
    // MARK: - Table View Delegate -
    
    public override func sectionIndexTitlesForTableView(tableView: UITableView) -> [AnyObject]! {
        var indexes: [AnyObject] = []
        
        if let sectionInfo = _sectionInfo? {
            for section in sectionInfo {
                indexes.append(section[0])
            }
        }

        return indexes;
    }
    
    public override func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        
        if let sectionInfo = _sectionInfo? {
            if let row: Int = sectionInfo[index][1] as? Int {
                let indexPath = NSIndexPath(forRow: row, inSection: 0)
                tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Top, animated: false)
            }
        }
        
        return -1;
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _dataModel.totalCount
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        if indexPath.row < _dataModel.albumsCount {
            
            let cell = tableView.dequeueReusableCellWithIdentifier(_reuseIdentifierAlbum, forIndexPath: indexPath) as CustomUITableViewCell
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.alwaysShowCoverArt = true
            cell.alwaysShowSubtitle = true
            cell.delegate = self
            
            let album = _dataModel.albumForTableViewRow(indexPath.row)
            
            if _sectionInfo != nil {
                cell.indexShowing = true
            }
            
            cell.associatedObject = album
            cell.coverArtId = album.coverArtId
            cell.title = album.title
            
            // Setup cell backgrond color
            cell.backgroundView = _viewObjects.createCellBackground(indexPath.row)
            
            return cell;
        } else {
            let cell = tableView.dequeueReusableCellWithIdentifier(_reuseIdentifierSong, forIndexPath: indexPath) as CustomUITableViewCell
            cell.alwaysShowSubtitle = true
            cell.accessoryType = UITableViewCellAccessoryType.None
            cell.delegate = self
            
            let song = _dataModel.songForTableViewRow(indexPath.row)
            
            cell.indexPath = indexPath
            cell.associatedObject = song
            cell.trackNumber = song.track
            cell.title = song.title
            cell.subTitle = song.artist == nil ? "" : song.artist
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
        return indexPath.row < _dataModel.albumsCount ? 50.0 : 44.0
    }
    
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if _viewObjects.isCellEnabled {
            if indexPath.row < _dataModel.albumsCount {
                let album = _dataModel.albumForTableViewRow(indexPath.row)
                
                let folderViewController = FolderViewController(album: album)
                self.pushViewControllerCustom(folderViewController)
            } else {
                let playedSong = _dataModel.playSongAtTableViewRow(indexPath.row)
                
                if !playedSong.isVideo {
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
        let message = "There was an error loading the album.\n\nError \(error?.code): \(error?.localizedDescription)"
        
        let alert = CustomUIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
        
        _viewObjects.hideLoadingScreen()
        
        _dataSourceDidFinishLoadingNewData()
        
        if _dataModel.songsCount == 0 && _dataModel.albumsCount == 0 {
            self.tableView.removeBottomShadow()
        }
    }
    
    public func loadingFinished(theLoader: ISMSLoader!) {
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
