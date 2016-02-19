//
//  ItemViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/22/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import libSub
import Foundation
import UIKit

class NewItemViewController: CustomUITableViewController, AsynchronousImageViewDelegate {
    
    private let reuseIdentifier = "Item Cell"
    private let foldersSectionIndex   = 0
    private let artistsSectionIndex   = 1
    private let albumsSectionIndex    = 2
    private let songsSectionIndex     = 3
    private let playlistsSectionIndex = 4
    
    private let viewModel: NewItemViewModel
    private var reloading: Bool = false
    // TODO: Use tuples after porting the data model
    private var sectionIndexes: [ISMSSectionIndex]?
    
    @IBOutlet var albumInfoView: UIView?
    @IBOutlet var albumInfoArtHolderView: UIView?
    @IBOutlet var albumInfoArtView: AsynchronousImageView?
    @IBOutlet var albumInfoLabelHolderView: UIView?
    @IBOutlet var albumInfoArtistLabel: UILabel?
    @IBOutlet var albumInfoAlbumLabel: UILabel?
    @IBOutlet var albumInfoTrackCountLabel: UILabel?
    @IBOutlet var albumInfoDurationLabel: UILabel?
    
    init(viewModel: NewItemViewModel) {
        self.viewModel = viewModel
        super.init(nibName: "NewItemViewController", bundle: nil)
    }
    
    required init(coder aDecoder: NSCoder) {
        fatalError("NSCoding not supported")
    }
    
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.edgesForExtendedLayout = UIRectEdge.None
        self.automaticallyAdjustsScrollViewInsets = false
        
        albumInfoArtView?.delegate = self
        
        viewModel.delegate = self
        if viewModel.loadModelsFromCache() {
            _addHeaderAndIndex()
        } else {
            viewModel.loadModelsFromWeb(nil)
        }
    }
    
    override func customizeTableView(tableView: UITableView!) {
        tableView.registerClass(NewItemUITableViewCell.self, forCellReuseIdentifier: reuseIdentifier)
    }
    
    override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.reloadData()
        
        _registerForNotifications()
    }
    
    override func viewWillDisappear(animated: Bool) {
        super.viewWillDisappear(animated)
        
        viewModel.cancelLoad()
        
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
    
    func currentPlaylistIndexChanged(notification: NSNotification?) {
        self.tableView.reloadData()
    }
    
    func songPlaybackStarted(notification: NSNotification?) {
        self.tableView.reloadData()
    }
    
    // MARK: - Loading -
    
    override func shouldSetupRefreshControl() -> Bool {
        return true
    }
    
    override func didPullToRefresh() {
        if !reloading {
            reloading = true
            viewModel.loadModelsFromWeb(nil)
        }
    }
    
    private func _dataSourceDidFinishLoadingNewData() {
        reloading = false
        self.refreshControl?.endRefreshing()
    }
    
    func cancelLoad() {
        viewModel.cancelLoad()
        self._dataSourceDidFinishLoadingNewData()
    }
    
    private func _addHeaderAndIndex() {
        let foldersCount = viewModel.folders.count
        let artistsCount = viewModel.artists.count
        let songsCount = viewModel.songs.count
        
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
            
            switch viewModel.rootItem {
            case let folder as ISMSFolder:
                albumInfoArtView!.coverArtId = folder.coverArtId?.stringValue
                albumInfoArtistLabel!.text = folder.name
                //albumInfoAlbumLabel!.text = _album!.title
                albumInfoDurationLabel!.text = NSString.formatTime(Double(viewModel.songsDuration))
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
    
    @IBAction func a_expandCoverArt(sender: AnyObject?) {
        var modalArtViewController: ModalAlbumArtViewController?
        
        switch viewModel.rootItem {
        case let folder as ISMSFolder:
            modalArtViewController = ModalAlbumArtViewController(title: folder.name, subtitle: nil, coverArtId: folder.coverArtId?.stringValue, numberOfTracks: viewModel.songs.count, albumLength: 0)
        default:
            break
        }
        
        if let controller = modalArtViewController {
            if IS_IPAD() {
                iSubAppDelegate.sharedInstance().ipadRootViewController.presentViewController(controller, animated: true, completion: nil)
            } else {
                self.presentViewController(controller, animated: true, completion: nil)
            }
        }
    }
    
    // MARK: - Table View Delegate -
    
    override func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]? {
        var titles: [String] = []
        
        if let sectionIndexes = sectionIndexes {
            for sectionIndex in sectionIndexes {
                titles.append(String(sectionIndex.letter))
            }
        }
        
        return titles;
    }
    
    override func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        if let sectionIndexes = sectionIndexes {
            let row = sectionIndexes[index].firstIndex
            
            // Find the section with items in it
            var section = -1
            if viewModel.folders.count > row {
                section = foldersSectionIndex
            } else if viewModel.artists.count > row {
                section = artistsSectionIndex
            } else if viewModel.albums.count > row {
                section = albumsSectionIndex
            } else if viewModel.songs.count > row {
                section = songsSectionIndex
            }
            
            if section >= 0 {
                let indexPath = NSIndexPath(forRow: row, inSection: section)
                tableView.scrollToRowAtIndexPath(indexPath, atScrollPosition: UITableViewScrollPosition.Top, animated: false)
            }
        }
        
        return -1;
    }
    
    override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 5
    }
    
    override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
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
    
    override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(reuseIdentifier, forIndexPath: indexPath) as! NewItemUITableViewCell
        cell.alwaysShowSubtitle = true
        //cell.delegate = self
        
        switch indexPath.section {
        case foldersSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.DisclosureIndicator
            cell.alwaysShowCoverArt = true
            if sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let folder = viewModel.folders[indexPath.row]
            cell.associatedObject = folder
            cell.coverArtId = folder.coverArtId?.stringValue
            cell.title = folder.name
            
            break
        case artistsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.None
            if sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let artist = viewModel.artists[indexPath.row]
            cell.associatedObject = artist
            cell.coverArtId = nil
            cell.title = artist.name
            
            break
        case albumsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.None
            if sectionIndexes != nil {
                cell.indexShowing = true
            }
            
            let album = viewModel.albums[indexPath.row]
            cell.associatedObject = album
            cell.coverArtId = album.coverArtId
            cell.title = album.name
            
            break
        case songsSectionIndex:
            cell.accessoryType = UITableViewCellAccessoryType.None
            
            let song = viewModel.songs[indexPath.row]
            cell.indexPath = indexPath
            cell.associatedObject = song
            cell.coverArtId = nil
            cell.trackNumber = song.trackNumber
            cell.title = song.title
            cell.subTitle = song.artist?.name
            cell.duration = song.duration
            // TODO: Readd this with new data model
            //cell.playing = song.isCurrentPlayingSong()
            
            if song.isFullyCached {
                cell.backgroundView = UIView()
                cell.backgroundView!.backgroundColor = ViewObjectsSingleton.sharedInstance().currentLightColor()
            } else {
                cell.backgroundView = UIView()
            }

            break
        default:
            break
        }
        
        return cell
    }
    
    override func tableView(tableView: UITableView, heightForRowAtIndexPath indexPath: NSIndexPath) -> CGFloat {
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
    
    override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if ViewObjectsSingleton.sharedInstance().isCellEnabled {
            switch indexPath.section {
            case foldersSectionIndex:
                let folder = self.viewModel.folders[indexPath.row]
                let folderLoader = ISMSFolderLoader()
                folderLoader.folderId = folder.folderId
                folderLoader.mediaFolderId = folder.mediaFolderId
                
                let viewModel = NewItemViewModel(loader: folderLoader)
                let viewController = NewItemViewController(viewModel: viewModel)
                self.pushViewControllerCustom(viewController)
            case artistsSectionIndex:
                break
            case albumsSectionIndex:
                break
            case songsSectionIndex:
                // TODO: Implement a way to just switch play index when we're playing from the same array to save time
                //playAll(songs: viewModel.songs, playIndex: indexPath.row)
                PlayQueue.sharedInstance.playSongs(viewModel.songs, playIndex: indexPath.row)
                
                let song = viewModel.songs[indexPath.row] as ISMSSong
                if song.contentType?.basicType == ISMSBasicContentType.Audio {
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
    
    func itemsChanged() {
        self.tableView.reloadData()
        _addHeaderAndIndex()
        
        _dataSourceDidFinishLoadingNewData()
    }
    
    func loadingError(error: String) {
        let message = "There was an error loading the folder.\n\nError \(error)"
        
        let alert = CustomUIAlertView(title: "Error", message: message, delegate: nil, cancelButtonTitle: "OK")
        alert.show()
        
        ViewObjectsSingleton.sharedInstance().hideLoadingScreen()
        
        _dataSourceDidFinishLoadingNewData()
    }
}