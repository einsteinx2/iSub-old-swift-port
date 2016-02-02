//
//  ItemViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class NewItemViewController: CustomUITableViewController, AsynchronousImageViewDelegate {
    
    private let _appDelegate = iSubAppDelegate.sharedInstance()
    private let _viewObjects = ViewObjectsSingleton.sharedInstance()
    private let _database = DatabaseSingleton.sharedInstance()
    
    private let _reuseIdentifier = "Item Cell"
    private let _foldersSectionIndex   = 0
    private let _artistsSectionIndex   = 1
    private let _albumsSectionIndex    = 2
    private let _songsSectionIndex     = 3
    private let _playlistsSectionIndex = 4
    
    private let _viewModel: NewItemViewModel
    private var _reloading: Bool = false
    // TODO: Use tuples after porting the data model
    private var _sectionIndexes: [ISMSSectionIndex]?
    
    private var _hasCachedItems: Bool = false
    
    @IBOutlet public var albumInfoView: UIView?
    @IBOutlet public var albumInfoArtHolderView: UIView?
    @IBOutlet public var albumInfoArtView: AsynchronousImageView?
    @IBOutlet public var albumInfoLabelHolderView: UIView?
    @IBOutlet public var albumInfoArtistLabel: UILabel?
    @IBOutlet public var albumInfoAlbumLabel: UILabel?
    @IBOutlet public var albumInfoTrackCountLabel: UILabel?
    @IBOutlet public var albumInfoDurationLabel: UILabel?
    
    public init(viewModel: NewItemViewModel) {
        _viewModel = viewModel
        
        super.init(nibName: "NewItemViewController", bundle: nil)
    }
    
    public required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge.None
        self.automaticallyAdjustsScrollViewInsets = false
        
        albumInfoArtView?.delegate = self
        
        _viewModel.delegate = self
        if _viewModel.loadModelsFromCache() {
            _addHeaderAndIndex()
        } else {
            _viewModel.loadModelsFromWeb(nil)
        }
    }
    
    public override func customizeTableView(tableView: UITableView!) {
        tableView.registerClass(NewItemUITableViewCell.self, forCellReuseIdentifier: _reuseIdentifier)
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
        
        _registerForNotifications()
    }
    
    public override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        _viewModel.cancelLoad()
        
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
            _viewModel.loadModelsFromWeb(nil)
        }
    }
    
    private func _dataSourceDidFinishLoadingNewData() {
        _reloading = false
        self.refreshControl?.endRefreshing()
    }
    
    public func cancelLoad() {
        _viewModel.cancelLoad()
        self._dataSourceDidFinishLoadingNewData()
    }
    
    private func _addHeaderAndIndex() {
        let foldersCount = _viewModel.folders.count
        let artistsCount = _viewModel.artists.count
        let songsCount = _viewModel.songs.count
        
        if (songsCount == 0 && foldersCount == 0) || artistsCount > 0 {
            self.tableView.tableHeaderView = nil;
            
        } else if songsCount > 0 {
            if self.tableView.tableHeaderView == nil {
                let headerHeight = albumInfoView!.height
                let headerFrame = CGRectMake(0, 0, 320, headerHeight)
                let headerView = UIView(frame: headerFrame)
                
                albumInfoArtView!.isLarge = true
                
                headerView.addSubview(albumInfoView!)
                
                self.tableView.tableHeaderView = headerView
            }
            
            switch _viewModel.rootItem {
            case let folder as ISMSFolder:
                albumInfoArtView!.coverArtId = folder.coverArtId?.stringValue
                albumInfoArtistLabel!.text = folder.name
                //albumInfoAlbumLabel!.text = _album!.title
                albumInfoDurationLabel!.text = NSString.formatTime(Double(_viewModel.songsDuration))
                albumInfoTrackCountLabel!.text = pluralizedString(count: songsCount, singularNoun: "Track")
            default:
                break
            }
            
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
        } else {
            self.tableView.tableHeaderView = nil
            if self.tableView.tableFooterView == nil {
                self.tableView.tableFooterView = UIView()
            }
        }
    }
    
    // MARK: - Actions -
    
    @IBAction public func a_expandCoverArt(sender: AnyObject?) {
        var modalArtViewController: ModalAlbumArtViewController?
        
        switch _viewModel.rootItem {
        case let folder as ISMSFolder:
            modalArtViewController = ModalAlbumArtViewController(title: folder.name, subtitle: nil, coverArtId: folder.coverArtId?.stringValue, numberOfTracks: _viewModel.songs.count, albumLength: 0)
        default:
            break
        }
        
        if let controller = modalArtViewController {
            if IS_IPAD() {
                _appDelegate.ipadRootViewController.presentViewController(controller, animated: true, completion: nil)
            } else {
                self.presentViewController(controller, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Table View Delegate -
    
    public override func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]? {
        var titles: [String] = []
        
        if let sectionIndexes = _sectionIndexes {
            for sectionIndex in sectionIndexes {
                titles.append(String(sectionIndex.letter))
            }
        }
        
        return titles;
    }
    
    public override func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        if let sectionIndexes = _sectionIndexes {
            let row = sectionIndexes[index].firstIndex
            
            // Find the section with items in it
            var section = -1
            if _viewModel.folders.count > row {
                section = _foldersSectionIndex
            } else if _viewModel.artists.count > row {
                section = _artistsSectionIndex
            } else if _viewModel.albums.count > row {
                section = _albumsSectionIndex
            } else if _viewModel.songs.count > row {
                section = _songsSectionIndex
            }
            
            if section >= 0 {
                let indexPath = NSIndexPath(forRow: row, inSection: section)
                tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Top, animated: false)
            }
        }
        
        return -1;
    }
    
    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 5
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        var count: Int? = nil
        
        switch section {
        case _foldersSectionIndex:   count = _viewModel.folders.count
        case _artistsSectionIndex:   count = _viewModel.artists.count
        case _albumsSectionIndex:    count = _viewModel.albums.count
        case _songsSectionIndex:     count = _viewModel.songs.count
        case _playlistsSectionIndex: count = _viewModel.playlists.count
        default: break
        }
        
        return count == nil ? 0 : count!
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(_reuseIdentifier, forIndexPath: indexPath) as! NewItemUITableViewCell
        cell.alwaysShowSubtitle = true
        //cell.delegate = self
        
        switch indexPath.section {
        case _foldersSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.alwaysShowCoverArt = true
            if _sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let folder = _viewModel.folders[indexPath.row]
            cell.associatedObject = folder
            cell.coverArtId = folder.coverArtId?.stringValue
            cell.title = folder.name
            
            break
        case _artistsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.None
            if _sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let artist = _viewModel.artists[indexPath.row]
            cell.associatedObject = artist
            cell.coverArtId = nil
            cell.title = artist.name
            
            break
        case _albumsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.None
            if _sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let album = _viewModel.albums[indexPath.row]
            cell.associatedObject = album
            cell.coverArtId = album.coverArtId
            cell.title = album.name
            
            break
        case _songsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.None
            
            let song = _viewModel.songs[indexPath.row]
            cell.indexPath = indexPath
            cell.associatedObject = song
            cell.coverArtId = nil
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

            break
        default:
            break
        }
        
        return cell
    }
    
    public override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
        var height: CGFloat = 0
        
        switch indexPath.section {
        case _foldersSectionIndex:
            height = ISMSSubfolderCellHeight
        case _artistsSectionIndex:
            height = ISMSArtistCellHeight
        case _albumsSectionIndex:
            height = ISMSAlbumCellHeight
        case _songsSectionIndex:
            height = ISMSSongCellHeight
        default:
            break
        }
        
        return ISMSNormalize(height)
    }
    
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if _viewObjects.isCellEnabled {
            switch indexPath.section {
            case _foldersSectionIndex:
                let folder = _viewModel.folders[indexPath.row]
                let folderLoader = ISMSFolderLoader()
                folderLoader.folderId = folder.folderId
                folderLoader.mediaFolderId = folder.mediaFolderId
                
                let itemViewController = ItemViewController(itemLoader: folderLoader)
                self.pushViewControllerCustom(itemViewController)
            case _artistsSectionIndex:
                break
            case _albumsSectionIndex:
                break
            case _songsSectionIndex:
                // TODO: Implement a way to just switch play index when we're playing from the same array to save time
                playAll(songs: _viewModel.songs, playIndex: indexPath.row)
                
                let song = _viewModel.songs[indexPath.row] as ISMSSong
                if !song.isVideo {
                    self.showPlayer()
                }
                break
            default:
                break
            }
        }
        else
        {
            self.tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
}

extension NewItemViewController : NewItemViewModelDelegate {
    
    public func itemsChanged() {
        self.tableView.reloadData()
        _addHeaderAndIndex()
        
        _dataSourceDidFinishLoadingNewData()
    }
    
    public func loadingError(error: String) {
        let message = "There was an error loading the folder.\n\nError \(error)"
        
        let alert = CustomUIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
        
        _viewObjects.hideLoadingScreen()
        
        _dataSourceDidFinishLoadingNewData()
    }
}