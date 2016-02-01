//
//  FoldersViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/20/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class FoldersViewController: CustomUITableViewController, UISearchBarDelegate, FolderDropdownControlDelegateSwift, CustomUITableViewCellDelegate {
    
    private lazy var _appDelegate = iSubAppDelegate.sharedInstance()
    private let _settings = SavedSettings.sharedInstance()
    private let _viewObjects = ViewObjectsSingleton.sharedInstance()
    private let _database = DatabaseSingleton.sharedInstance()
    
    private let _reuseIdentifier = "Artist Cell"
    
    private var _mediaFolders = ISMSMediaFolder.allMediaFoldersIncludingAllFolders() as [ISMSMediaFolder]
    private var _folders: [ISMSFolder]?
    private var _filteredFolders: [ISMSFolder]?
    
    private var _sectionIndexes: [ISMSSectionIndex]?
    
    private var _loaders: [ISMSLoader] = []
    
    private var _reloading: Bool = false
    private var _letUserSelectRow: Bool = false
    private var _searching: Bool = false
    private var _countShowing: Bool = false
    
    private let _headerView: UIView = UIView()
    private let _searchBar: UISearchBar = UISearchBar()
    private let _countLabel: UILabel = UILabel()
    private let _reloadTimeLabel: UILabel = UILabel()
    private let _blockerButton: UIButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    private let _searchOverlay: UIView = UIView()
    private let _dismissButton: UIButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    private let _dropdown: FolderDropdownControlSwift = FolderDropdownControlSwift(frame: CGRectZero)
    
    private lazy var _reloadTimeFormatter: NSDateFormatter = {
        let formatter = NSDateFormatter()
        formatter.dateStyle = NSDateFormatterStyle.MediumStyle
        formatter.timeStyle = NSDateFormatterStyle.ShortStyle
        return formatter
    }()
    
    // MARK: - Lifecycle -
    
    public override init() {
        super.init()
    }
    
    public override init(style: UITableViewStyle) {
        super.init(style: style)
    }
    
    public override init(nibName nibNameOrNil: String?, bundle nibBundleOrNil: NSBundle?) {
        super.init(nibName: nibNameOrNil, bundle: nibBundleOrNil)
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Folders"
        
        _letUserSelectRow = true
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "_serverSwitched:", name: ISMSNotification_ServerSwitched, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "_updateFolders:", name: ISMSNotification_ServerCheckPassed, object: nil)

        // Hide the folder selector when there is only one folder
        if !IS_IPAD()
        {
            let y: CGFloat = _mediaFolders.count <= 2 ? 86.0 : 50.0
            let contentOffset = CGPointMake(0, y)
            
            self.tableView.setContentOffset(contentOffset, animated: false)
        }
        
        _initialLoad()
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        Flurry.logEvent("FoldersTab");
    }
    
    override public func customizeTableView(tableView: UITableView!) {
        tableView.registerClass(CustomUITableViewCell.self, forCellReuseIdentifier: _reuseIdentifier)
        tableView.rowHeight = ISMSNormalize(ISMSArtistCellHeight);
    }
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ISMSNotification_ServerSwitched, object: nil)
        NSNotificationCenter.defaultCenter().removeObserver(self, name: ISMSNotification_ServerCheckPassed, object: nil)
    }
    
    // MARK: - Loading -
    
    public override func shouldSetupRefreshControl() -> Bool {
        return true
    }
    
    public override func didPullToRefresh() {
        if !_reloading {
            _reloading = true
            let selectedFolderId = _settings.rootFoldersSelectedFolderId == nil ? -1 : Int(_settings.rootFoldersSelectedFolderId)
            _loadData(selectedFolderId)
        }
    }
    
    private func _dataSourceDidFinishLoadingNewData() {
        _reloading = false
        self.refreshControl?.endRefreshing()
    }
    
    private func _initialLoad() {
        // Load data if it's not cached yet and we're not processing the Artists/Albums/Songs tabs
        let selectedFolderId = _settings.rootFoldersSelectedFolderId == nil ? -1 : Int(_settings.rootFoldersSelectedFolderId)
        if _mediaFolders.count <= 1 {
            _updateMediaFolders()
        } else {
            if selectedFolderId == -1 {
                _folders = ISMSMediaFolder.allRootFolders() as? [ISMSFolder]
            } else {
                let mediaFolder = ISMSMediaFolder(mediaFolderId: selectedFolderId)
                _folders = mediaFolder.rootFolders() as? [ISMSFolder]
            }
            
            if !_countShowing {
                _addCount()
            } else {
                _updateCount()
            }
            _sectionIndexes = sectionIndexesForItems(_folders!)
            self.tableView.reloadData()
        }
    }
    
    private func _updateCount() {
        if let count = _folders?.count {
            if count == 1 {
                _countLabel.text = "\(count) Folder"
            } else {
                _countLabel.text = "\(count) Folders"
            }
        }
        
        if let reloadTime = _settings.rootFoldersReloadTime {
            _reloadTimeLabel.text = "last reload: \(_reloadTimeFormatter.stringFromDate(reloadTime))"
        }
    }
    
    private func _removeCount() {
        self.tableView.tableHeaderView = nil
        _countShowing = false
    }
    
    private func _addCount() {
        _countShowing = true
        
        _headerView.frame = CGRectMake(0, 0, 320, 126)
        _headerView.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        _headerView.backgroundColor = ISMSHeaderColor
        
        // This is a hack to prevent unwanted taps in the header, but it messes with voice over
        if !UIAccessibilityIsVoiceOverRunning() {
            _blockerButton.autoresizingMask = UIViewAutoresizing.FlexibleWidth
            _blockerButton.frame = _headerView.frame
            _headerView.addSubview(_blockerButton)
        }
        
        _countLabel.frame = CGRectMake(0, 5, 320, 30)
        _countLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        _countLabel.backgroundColor = UIColor.clearColor()
        _countLabel.textColor = ISMSHeaderTextColor
        _countLabel.textAlignment = NSTextAlignment.Center
        _countLabel.font = ISMSBoldFont(30)
        _headerView.addSubview(_countLabel)
        
        _reloadTimeLabel.frame = CGRectMake(0, 36, 320, 12)
        _reloadTimeLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        _reloadTimeLabel.backgroundColor = UIColor.clearColor()
        _reloadTimeLabel.textColor = ISMSHeaderTextColor
        _reloadTimeLabel.textAlignment = NSTextAlignment.Center
        _reloadTimeLabel.font = ISMSRegularFont(11)
        _headerView.addSubview(_reloadTimeLabel)
        
        _searchBar.frame = CGRectMake(0, 86, 320, 40)
        _searchBar.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        _searchBar.delegate = self
        _searchBar.autocorrectionType = UITextAutocorrectionType.No
        _searchBar.placeholder = "Folder name"
        _headerView.addSubview(_searchBar)
        
        _dropdown.frame = CGRectMake(50, 53, 220, 30)
        _dropdown.delegate = self
        _dropdown.folders = _mediaFolders
        let selectedFolderId = _settings.rootFoldersSelectedFolderId == nil ? -1 : Int(_settings.rootFoldersSelectedFolderId)
        _dropdown.selectFolderWithId(selectedFolderId)
        
        _headerView.addSubview(_dropdown)
        
        _updateCount()
        
        // Special handling for voice over users
        if UIAccessibilityIsVoiceOverRunning() {
            // Add a refresh button
            let voiceOverRefresh = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
            voiceOverRefresh.frame = CGRectMake(0, 0, 50, 50)
            voiceOverRefresh.addTarget(self, action: "a_reload:", forControlEvents: UIControlEvents.TouchUpInside)
            voiceOverRefresh.accessibilityLabel = "Reload Folders"
            _headerView.addSubview(voiceOverRefresh)
            
            // Resize the two labels at the top so the refresh button can be pressed
            _countLabel.frame = CGRectMake(50, 5, 220, 30)
            _reloadTimeLabel.frame = CGRectMake(50, 36, 220, 12)
        }
        
        self.tableView.tableHeaderView = _headerView
    }
    
    private func _updateMediaFolders() {
        let loader = ISMSMediaFoldersLoader(callbackBlock: { (success: Bool, error: NSError!, loader: ISMSLoader!) -> Void in
            let loader = loader as ISMSMediaFoldersLoader
            if success {
                loader.persistModels()
                self._mediaFolders = ISMSMediaFolder.allMediaFoldersIncludingAllFolders() as [ISMSMediaFolder]
                self._dropdown.folders = self._mediaFolders
                let selectedFolderId = self._settings.rootFoldersSelectedFolderId == nil ? -1 : Int(self._settings.rootFoldersSelectedFolderId)
                self._dropdown.selectFolderWithId(selectedFolderId)
                self._loadData(selectedFolderId)
            } else {
                // TODO: failed.  how to report this to the user?
            }
        })
        
        loader.startLoad()
    }
    
    public func cancelLoad() {
        for loader in _loaders {
            loader.cancelLoad()
        }
        _loaders.removeAll(keepCapacity: false)
        _viewObjects.hideLoadingScreen()
        self._dataSourceDidFinishLoadingNewData()
    }
    
    private func _loadData(folderId: Int) {
        print("_loadData called for \(folderId)")
        _viewObjects.isArtistsLoading = true
        _viewObjects.showAlbumLoadingScreen(_appDelegate.window, sender:self)
        
        var i = _mediaFolders.count
        var allFolders: [ISMSFolder] = []

        println("i = \(i)  mediaFolders = \(_mediaFolders)")
        if _mediaFolders.count <= 1 {
            println("_mediaFolders.count = \(_mediaFolders.count)")
        }
        
        for mediaFolder in _mediaFolders {
            // Don't load the "All Folders" placeholder
            if mediaFolder.mediaFolderId == -1 {
                i--
                println("mediaFolderId = \(mediaFolder.mediaFolderId) so skipping, i = \(i)")
                continue
            }
            
            // Only process if folderId == -1 (meaning load all folders) or folderId matches this media folder
            if folderId != -1 && folderId != mediaFolder.mediaFolderId {
                i--
                println("mediaFolderId = \(mediaFolder.mediaFolderId) and folderId = \(folderId) so skipping, i = \(i)")
                continue
            }

            let loader = ISMSNewRootFoldersLoader { (success: Bool, error: NSError?, theLoader: ISMSLoader!) -> Void in
                if success {
                    let loader = theLoader as ISMSNewRootFoldersLoader
                    loader.persistModels()
                    if let folders = loader.folders as? [ISMSFolder] {
                        allFolders.extend(folders)
                    }
                }

                i--
                if i == 0 {
                    self._folders = allFolders

                    if self._countShowing {
                        self._updateCount()
                    } else {
                        self._addCount()
                    }

                    self._sectionIndexes = sectionIndexesForItems(self._folders!)
                    self.tableView.reloadData()

                    if !IS_IPAD() {
                        self.tableView.backgroundColor = UIColor.clearColor()
                    }

                    self._viewObjects.isArtistsLoading = false

                    // Hide the loading screen
                    self._viewObjects.hideLoadingScreen()

                    self._dataSourceDidFinishLoadingNewData()
                }

                let index = (self._loaders as NSArray).indexOfObject(theLoader)
                self._loaders.removeAtIndex(index)
            }
            loader.mediaFolderId = mediaFolder.mediaFolderId
            _loaders.append(loader)
            loader.startLoad()
            println("started load for mediaFolderId \(mediaFolder.mediaFolderId)")
        }
    }
//    
//    private func _buildSectionIndexes() {
//        func isDigit(c: Character) -> Bool {
//            let cset = NSCharacterSet.decimalDigitCharacterSet()
//            let s = String(c)
//            let ix = s.startIndex
//            let ix2 = s.endIndex
//            let result = s.rangeOfCharacterFromSet(cset, options: nil, range: ix..<ix2)
//            return result != nil
//        }
//        
//        if let folders = _folders {
//            var sectionIndexes: [SectionIndex] = []
//            var lastFirstLetter: Character? = nil
//            
//            var index: Int = 0
//            var count: Int = 0
//            for folder in folders {
//                let name = folder.nameIgnoringArticles()
//                var firstLetter = Array(name.uppercaseString)[0]
//                
//                // Sort digits to the end in a single "#" section
//                if isDigit(firstLetter) {
//                    firstLetter = "#"
//                }
//                
//                if lastFirstLetter == nil {
//                    lastFirstLetter = firstLetter
//                    sectionIndexes.append(SectionIndex(firstIndex: 0, sectionCount: 0, letter: firstLetter))
//                }
//                
//                if lastFirstLetter != firstLetter {
//                    lastFirstLetter = firstLetter
//                    
//                    if var last = sectionIndexes.last {
//                        last.sectionCount = count
//                        sectionIndexes.removeLast()
//                        sectionIndexes.append(last)
//                    }
//                    count = 0
//                    
//                    sectionIndexes.append(SectionIndex(firstIndex: index, sectionCount: 0, letter: firstLetter))
//                }
//                
//                index++
//                count++
//            }
//            
//            if var last = sectionIndexes.last {
//                last.sectionCount = count
//                sectionIndexes.removeLast()
//                sectionIndexes.append(last)
//            }
//            
//            _sectionIndexes = sectionIndexes
//        }
//    }
    
    // MARK: - Folder Dropdown Delegate -
    
    public func folderDropdownMoveViewsY(y: CGFloat) {
        
        self.tableView.tableHeaderView!.height += y;
        _blockerButton.frame = self.tableView.tableHeaderView!.frame
        _searchBar.y += y
        
        self.tableView.tableHeaderView = self.tableView.tableHeaderView;
    }
    
    public func folderDropdownViewsFinishedMoving() {
        
    }
    
    public func folderDropdownSelectFolder(folderId: Int) {
        // Save the default
        _settings.rootFoldersSelectedFolderId = folderId
        
        // Reload the data
        _searching = false
        if folderId == -1 {
            _folders = ISMSMediaFolder.allRootFolders() as? [ISMSFolder]
            _updateCount()
            _sectionIndexes = sectionIndexesForItems(_folders!)
            self.tableView.reloadData()
        } else {
            if let mediaFolder = ISMSMediaFolder(mediaFolderId: folderId) {
                _folders = mediaFolder.rootFolders() as? [ISMSFolder]
                
                if _folders?.count > 0 {
                    _updateCount()
                    _sectionIndexes = sectionIndexesForItems(_folders!)
                    self.tableView.reloadData()
                } else {
                    _loadData(folderId)
                }
            }
        }
    }
    
    // MARK: - Notifications -
    
    public func _serverSwitched(notification: NSNotification) {
        _mediaFolders = ISMSMediaFolder.allMediaFoldersIncludingAllFolders() as [ISMSMediaFolder]
        _initialLoad()
    }
    
    public func _updateFolders(notification: NSNotification) {
        _updateMediaFolders()
    }
    
    // MARK: - Actions -
    
    private func a_reload(sender: UIButton) {
        let selectedFolderId = _settings.rootFoldersSelectedFolderId == nil ? -1 : Int(_settings.rootFoldersSelectedFolderId)
        _loadData(selectedFolderId)
    }
    
    // MARK: - Search Bar -
    
    private func _createSearchOverlay() {
        _searchOverlay.frame = CGRectMake(0, 0, 480, 480)
        _searchOverlay.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight]
        _searchOverlay.backgroundColor = UIColor(white: 0.0, alpha: 0.80)
        _searchOverlay.alpha = 0.0
        self.tableView.tableFooterView = _searchOverlay
        
        _dismissButton.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleHeight]
        _dismissButton.addTarget(self, action: "a_doneSearching:", forControlEvents: UIControlEvents.TouchUpInside)
        _dismissButton.frame = self.view.bounds
        _dismissButton.enabled = false
        _searchOverlay.addSubview(_dismissButton)
        
        // Animate the search overlay on screen
        UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
            self._searchOverlay.alpha = 1.0
            self._dismissButton.enabled = true
        }, completion: nil)
    }
    
    private func _hideSearchOverlay() {
        if _searchOverlay.alpha > 0.0 {
            // Animate the search overlay off screen
            UIView.animateWithDuration(0.3, delay: 0.0, options: UIViewAnimationOptions.CurveEaseOut, animations: {
                    self._searchOverlay.alpha = 0.0
                    self._dismissButton.enabled = false
                }, completion: { (finished: Bool) in
                    self._searchOverlay.removeFromSuperview()
                    if self.tableView.tableFooterView == nil {
                        self.tableView.tableFooterView = UIView()
                    }
                })
        }
    }
    
    public func searchBarTextDidBeginEditing(searchBar: UISearchBar) {
        if _searching {
            return
        }
        
        // Remove the index bar
        _searching = true
        _filteredFolders = _folders
        self.tableView.reloadData()
        
        _dropdown.closeDropdownFast()
        self.tableView.setContentOffset(CGPointMake(0, 86), animated: true)
        
        if countElements(searchBar.text) == 0 {
            _createSearchOverlay()
            
            _letUserSelectRow = false
            self.tableView.scrollEnabled = false
        }
        
        //Add the done button.
        self.navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: UIBarButtonSystemItem.Done, target: self, action: "a_doneSearching:")
    }
    
    public func searchBar(searchBar: UISearchBar, textDidChange searchText: String) {
        if countElements(searchText) > 0 {
            self._hideSearchOverlay()
            
            _letUserSelectRow = true
            self.tableView.scrollEnabled = true
            
            let searchTerm = _searchBar.text.lowercaseString
            _filteredFolders = _folders?.filter {
                $0.name.lowercaseString.rangeOfString(searchTerm) != nil
            }
            
            self.tableView.reloadData()
        } else {
            self._createSearchOverlay()
            
            _letUserSelectRow = false
            self.tableView.scrollEnabled = false
            
            _filteredFolders = _folders
            
            self.tableView.reloadData()
            
            self.tableView.setContentOffset(CGPointMake(0, 86), animated: false)
        }
    }
    
    public func searchBarSearchButtonClicked(searchBar: UISearchBar) {
        _searchBar.resignFirstResponder()
    }
    
    public func searchBarShouldEndEditing(searchBar: UISearchBar) -> Bool {
        self._hideSearchOverlay()
        return true
    }
    
    public func a_doneSearching(sender: UIButton) {
        self._updateCount()
        
        _searchBar.text = ""
        _searchBar.resignFirstResponder()
        
        _letUserSelectRow = true
        _searching = false
        self.navigationItem.leftBarButtonItem = nil
        self.tableView.scrollEnabled = true
        
        self._hideSearchOverlay()
        
        _filteredFolders = nil
        
        self.tableView.reloadData()
        
        self.tableView.setContentOffset(CGPointMake(0, 86), animated: true)
    }
    
    // MARK: - TableView -
    
    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if !_searching {
            if let sectionIndexes = _sectionIndexes {
                return sectionIndexes.count
            }
        }
        
        return 1
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if !_searching {
            if let sectionIndexes = _sectionIndexes {
                if sectionIndexes.count > section {
                    return sectionIndexes[section].sectionCount
                }
            }
        }
        
        let array = _searching ? _filteredFolders : _folders
        return array == nil ? 0 : array!.count
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(_reuseIdentifier, forIndexPath: indexPath) as! CustomUITableViewCell
        cell.delegate = self
        
        var folder: ISMSFolder? = nil
        if _searching {
            if let filteredFolders = _filteredFolders {
                if indexPath.row < filteredFolders.count {
                    folder = filteredFolders[indexPath.row]
                }
            }
        } else {
            var index = indexPath.row
            if let sectionIndexes = _sectionIndexes {
                if indexPath.section < sectionIndexes.count {
                    index += sectionIndexes[indexPath.section].firstIndex
                }
            }
            
            if let folders = _folders {
                if index < folders.count {
                    folder = folders[index]
                }
            }
        }
        
        cell.associatedObject = folder
        cell.title = folder?.name
        
        return cell;
    }
    
    public override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if !_searching {
            if let sectionIndexes = _sectionIndexes {
                if sectionIndexes.count > section {
                    return String(sectionIndexes[section].letter)
                }
            }
        }
        
        return ""
    }
    
    public override func sectionIndexTitlesForTableView(tableView: UITableView) -> [String]! {
        if _searching {
            return nil
        }
        
        var titles: [String] = []
        titles.append("{search}")
        
        if let sectionIndexes = _sectionIndexes {
            for sectionIndex in sectionIndexes {
                titles.append(String(sectionIndex.letter))
            }
        }
        
        return titles;
    }
    
    public override func tableView(tableView: UITableView, sectionForSectionIndexTitle title: String, atIndex index: Int) -> Int {
        if _searching {
            return -1
        }
        
        if (index == 0) {
            let y: CGFloat  = _dropdown.folders == nil || _dropdown.folders?.count == 2 ? 86.0 : 50.0
            self.tableView.setContentOffset(CGPointMake(0, y), animated:false)
            
            return -1;
        }
        
        return index - 1;
    }
    
    public override func tableView(tableView: UITableView, willSelectRowAtIndexPath indexPath: NSIndexPath) -> NSIndexPath? {
        if _letUserSelectRow {
            return indexPath
        } else {
            return nil
        }
    }
    
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if _viewObjects.isCellEnabled {
            var folder: ISMSFolder? = nil
            if _searching {
                folder = _filteredFolders?[indexPath.row]
            } else {
                folder = _folders?[indexPath.row]
            }
            
            if let folder = folder {
//                let artist = ISMSArtist(name: folder.name, andArtistId: folder.folderId.stringValue)
//                let folderViewController = FolderViewController(artist: artist)
//                self.pushViewControllerCustom(folderViewController)
                
                let folderLoader = ISMSFolderLoader()
                folderLoader.folderId = folder.folderId
                folderLoader.mediaFolderId = folder.mediaFolderId
                
                let itemViewController = ItemViewController(itemLoader: folderLoader)
                self.pushViewControllerCustom(itemViewController)
            }
        }
        else
        {
            self.tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
    
    // MARK: - CustomUITableViewCell Delegate -
    
    public func tableCellDownloadButtonPressed(cell: CustomUITableViewCell) {
        if let artist = cell.associatedObject as? ISMSArtist {
            _database.downloadAllSongs(artist.artistId.stringValue, artist: artist)
        }
        
        cell.overlayView?.disableDownloadButton()
    }
    
    public func tableCellQueueButtonPressed(cell: CustomUITableViewCell) {
        if let artist = cell.associatedObject as? ISMSArtist {
            _database.queueAllSongs(artist.artistId.stringValue, artist:artist)
        }
    }
}