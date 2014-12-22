//
//  FoldersViewController.swift
//  iSub
//
//  Created by Benjamin Baron on 12/20/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class FoldersViewController: CustomUITableViewController, UISearchBarDelegate, ISMSLoaderDelegate, FolderDropdownControlDelegateSwift, CustomUITableViewCellDelegate {
    
    private lazy var _appDelegate = iSubAppDelegate.sharedInstance()
    private let _settings = SavedSettings.sharedInstance()
    private let _viewObjects = ViewObjectsSingleton.sharedInstance()
    private let _database = DatabaseSingleton.sharedInstance()
    
    private let _reuseIdentifier = "Artist Cell"
    
    private var _dataModel: SUSRootFoldersDAO = SUSRootFoldersDAO()
    
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
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
    }
    
    private func _createDataModel() {
        _dataModel = SUSRootFoldersDAO(delegate: self)
        _dataModel.selectedFolderId = _settings.rootFoldersSelectedFolderId
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        _createDataModel()
        
        self.title = "Folders"
        
        _letUserSelectRow = true
        
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "_serverSwitched:", name: ISMSNotification_ServerSwitched, object: nil)
        NSNotificationCenter.defaultCenter().addObserver(self, selector: "_updateFolders:", name: ISMSNotification_ServerCheckPassed, object: nil)

        // Hide the folder selector when there is only one folder
        if !IS_IPAD()
        {
            let y: CGFloat = _dropdown.folders?.count <= 2 ? 86.0 : 50.0
            let contentOffset = CGPointMake(0, y)
            
            self.tableView.setContentOffset(contentOffset, animated: false)
        }
        
        // Add the count if we've cached the folder data already
        if _dataModel.isRootFolderIdCached {
            _addCount()
        }
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        // Load data if it's not cached yet and we're not processing the Artists/Albums/Songs tabs
        if !SUSAllSongsLoader.isLoading() && !_viewObjects.isArtistsLoading && !_dataModel.isRootFolderIdCached {
            _loadData(_settings.rootFoldersSelectedFolderId)
        }
        
        Flurry.logEvent("FoldersTab");
    }
    
    override public func customizeTableView(tableView: UITableView!) {
        tableView.registerClass(CustomUITableViewCell.self, forCellReuseIdentifier: _reuseIdentifier)
        tableView.rowHeight = 44.0;
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
            _loadData(_settings.rootFoldersSelectedFolderId)
        }
    }
    
    private func _dataSourceDidFinishLoadingNewData() {
        _reloading = false
        self.refreshControl?.endRefreshing()
    }
    
    private func _updateCount() {
        if _dataModel.count == 1 {
            _countLabel.text = "\(_dataModel.count) Folder"
        } else {
            _countLabel.text = "\(_dataModel.count) Folders"
        }
        
        _reloadTimeLabel.text = "last reload: \(_reloadTimeFormatter.stringFromDate(_settings.rootFoldersReloadTime))"
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
        let dropdownFolders: NSDictionary? = SUSRootFoldersDAO.folderDropdownFolders()
        if dropdownFolders != nil {
            _dropdown.folders = dropdownFolders;
        } else {
            _dropdown.folders = NSDictionary(object: "All Folders", forKey: -1)
        }
        _dropdown.selectFolderWithId(Int(_dataModel.selectedFolderId))
        
        _headerView.addSubview(_dropdown)
        
        self._updateCount()
        
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
    
    public func cancelLoad() {
        _dataModel.cancelLoad()
        _viewObjects.hideLoadingScreen()
        self._dataSourceDidFinishLoadingNewData()
    }
    
    private func _loadData(folderId: NSNumber?) {
        _dropdown.updateFolders()
        
        _viewObjects.isArtistsLoading = true
        
        _viewObjects.showAlbumLoadingScreen(_appDelegate.window, sender:self)
        
        _dataModel.selectedFolderId = folderId
        _dataModel.startLoad()
    }
    
    public func loadingFailed(theLoader: ISMSLoader!, withError error: NSError!) {
        _viewObjects.isArtistsLoading = false
        
        // Hide the loading screen
        _viewObjects.hideLoadingScreen()
        
        self._dataSourceDidFinishLoadingNewData()
        
        // Inform the user that the connection failed.
        let alert = CustomUIAlertView(title: "Error", message: "There was an error loading the artist list.\n\nCould not create the network request.", delegate: nil, cancelButtonTitle: "OK")
        alert.show()
    }
    
    public func loadingFinished(theLoader: ISMSLoader!) {
        if _countShowing {
            self._updateCount()
        } else {
            self._addCount()
        }
        
        self.tableView.reloadData()
        
        if !IS_IPAD() {
            self.tableView.backgroundColor = UIColor.clearColor()
        }
        
        _viewObjects.isArtistsLoading = false
        
        // Hide the loading screen
        _viewObjects.hideLoadingScreen()
        
        self._dataSourceDidFinishLoadingNewData()
    }
    
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
        _dropdown.selectFolderWithId(folderId)
        
        // Save the default
        _settings.rootFoldersSelectedFolderId = folderId
        
        // Reload the data
        _dataModel.selectedFolderId = folderId
        _searching = false
        if _dataModel.isRootFolderIdCached {
            self.tableView.reloadData()
            self._updateCount()
        } else {
            self._loadData(folderId)
        }
    }
    
    // MARK: - Notifications -
    
    public func _serverSwitched(notification: NSNotification) {
        _createDataModel()
        if _dataModel.isRootFolderIdCached {
            self.tableView.reloadData()
            _removeCount()
        }
        
        folderDropdownSelectFolder(-1)
    }
    
    public func _updateFolders(notification: NSNotification) {
        _dropdown.updateFolders()
    }
    
    // MARK: - Actions -
    
    private func a_reload(sender: UIButton) {
        if !SUSAllSongsLoader.isLoading() {
            _loadData(_settings.rootFoldersSelectedFolderId)
        }
        else
        {
            let alert = CustomUIAlertView(title: "Please Wait", message: "You cannot reload the Artists tab while the Albums or Songs tabs are loading", delegate: self, cancelButtonTitle: "OK")
            alert.show()
        }
    }
    
    // MARK: - Search Bar -
    
    private func _createSearchOverlay() {
        
        _searchOverlay.frame = CGRectMake(0, 0, 480, 480)
        _searchOverlay.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
        _searchOverlay.backgroundColor = UIColor(white: 0.0, alpha: 0.80)
        _searchOverlay.alpha = 0.0
        self.tableView.tableFooterView = _searchOverlay
        
        _dismissButton.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
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
        _dataModel.clearSearchTable()
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
            
            _dataModel.searchForFolderName(_searchBar.text)
            
            self.tableView.reloadData()
        } else {
            self._createSearchOverlay()
            
            _letUserSelectRow = false
            self.tableView.scrollEnabled = false
            
            _dataModel.clearSearchTable()
            
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
        
        _dataModel.clearSearchTable()
        
        self.tableView.reloadData()
        
        self.tableView.setContentOffset(CGPointMake(0, 86), animated: true)
    }
    
    // MARK: - TableView -
    
    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        if _searching {
            return 1
        } else {
            let count = _dataModel.indexNames.count
            return count;
        }
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        if _searching {
            let count = _dataModel.searchCount
            return Int(count)
        } else {
            if _dataModel.indexCounts.count > section {
                let count = _dataModel.indexCounts[section] as Int
                return count
            }
            
            return 0;
        }
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(_reuseIdentifier, forIndexPath: indexPath) as CustomUITableViewCell
        cell.delegate = self
        
        var anArtist: ISMSArtist? = nil
        if _searching {
            anArtist = _dataModel.artistForPositionInSearch(indexPath.row + 1)
        } else {
            let count = _dataModel.indexPositions == nil ? 0 : _dataModel.indexPositions.count
            if count > indexPath.section {
                let sectionStartIndex = _dataModel.indexPositions[indexPath.section] as UInt
                anArtist = _dataModel.artistForPosition(sectionStartIndex + indexPath.row)
            }
        }
        
        cell.associatedObject = anArtist
        cell.title = anArtist?.name
        
        return cell;
    }
    
    public override func tableView(tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        if _searching {
            return ""
        }
        
        if _dataModel.indexNames.count == 0 {
            return ""
        }
        
        let title = _dataModel.indexNames[section] as String
        return title;
    }
    
    public override func sectionIndexTitlesForTableView(tableView: UITableView) -> [AnyObject]! {
        if _searching {
            return nil
        }
        
        var titles = NSMutableArray()
        titles.addObject("{search}")
        titles.addObjectsFromArray(_dataModel.indexNames)
        
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
            var anArtist: ISMSArtist? = nil
            if _searching {
                anArtist = _dataModel.artistForPositionInSearch(indexPath.row + 1)
            } else {
                if _dataModel.indexPositions.count > indexPath.section {
                    let sectionStartIndex = _dataModel.indexPositions[indexPath.section] as UInt
                    anArtist = _dataModel.artistForPosition(sectionStartIndex + indexPath.row)
                }
            }
            
            let albumViewController = FolderViewController(artist: anArtist, orAlbum: nil)
            self.pushViewControllerCustom(albumViewController)
        }
        else
        {
            self.tableView.deselectRowAtIndexPath(indexPath, animated: false)
        }
    }
    
    // MARK: - CustomUITableViewCell Delegate -
    
    public func tableCellDownloadButtonPressed(cell: CustomUITableViewCell) {
        if let artist = cell.associatedObject as? ISMSArtist {
            _database.downloadAllSongs(artist.artistId, artist: artist)
        }
        
        cell.overlayView?.disableDownloadButton()
    }
    
    public func tableCellQueueButtonPressed(cell: CustomUITableViewCell) {
        if let artist = cell.associatedObject as? ISMSArtist {
            _database.queueAllSongs(artist.artistId, artist:artist)
        }
    }
}