//
//  BookmarksViewController.swift
//  iSub
//
//  Created by Ben Baron on 5/10/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class BookmarksViewController: CustomUITableViewController {
    
    private let _database = DatabaseSingleton.sharedInstance()
    private let _settings = SavedSettings.sharedInstance()
    private let _playlist = PlaylistSingleton.sharedInstance()
    private let _music = MusicSingleton.sharedInstance()
    private let _jukebox = JukeboxSingleton.sharedInstance()
    
    private let _reuseIdentifier = "Bookmark Cell"
    
    private var _multiDeleteList = [Int]()
    
    private var _isNoBookmarksScreenShowing = false
    
    private let _noBookmarksScreen = UIImageView()
    private let _textLabel = UILabel()
    private let _headerView = UIView()
    private let _bookmarkCountLabel = UILabel()
    private let _deleteBookmarksButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    private let _deleteBookmarksLabel = UILabel()
    private let _editBookmarksLabel = UILabel()
    private let _editBookmarksButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    private var _bookmarkIds = [Int]()
    
    // MARK: - View Lifecycle -
    
    deinit {
        NSNotificationCenter.defaultCenter().removeObserver(self)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
        
        self.title = "Bookmarks"
    }
    
    public override func customizeTableView(tableView: UITableView!) {
        tableView.registerClass(CustomUITableViewCell.self, forCellReuseIdentifier: _reuseIdentifier)
        
        tableView.separatorColor = UIColor.clearColor()
        tableView.rowHeight = ISMSAlbumCellHeight + ISMSCellHeaderHeight
    }
    
    public override func viewWillAppear(animated: Bool) {
        super.viewWillAppear(animated)
        
        self.tableView.tableHeaderView = nil
        
        if _isNoBookmarksScreenShowing {
            _noBookmarksScreen.removeFromSuperview()
            _isNoBookmarksScreenShowing = false
        }
        
        // TODO: Switch back to intForQuery once the header issues are sorted
        var bookmarksCount = 0;
        _database.bookmarksDbQueue.inDatabase({ (db: FMDatabase!) in
            let result = db.executeQuery("SELECT COUNT(*) FROM bookmarks", withArgumentsInArray:[])
            if result.next() {
                bookmarksCount = Int(result.intForColumnIndex(0))
            }
        })
        
        if bookmarksCount == 0 {
            _isNoBookmarksScreenShowing = true
            
            if _noBookmarksScreen.subviews.count == 0 {
                _noBookmarksScreen.autoresizingMask = [UIViewAutoresizing.FlexibleLeftMargin, UIViewAutoresizing.FlexibleTopMargin, UIViewAutoresizing.FlexibleRightMargin, UIViewAutoresizing.FlexibleBottomMargin]
                _noBookmarksScreen.frame = CGRectMake(40, 100, 240, 180)
                _noBookmarksScreen.center = CGPointMake(self.view.bounds.size.width / 2.0, self.view.bounds.size.height / 2.0)
                _noBookmarksScreen.image = UIImage(named:"loading-screen-image")
                _noBookmarksScreen.alpha = 0.80
                
                _textLabel.backgroundColor = UIColor.clearColor()
                _textLabel.textColor = UIColor.whiteColor()
                _textLabel.font = ISMSBoldFont(30)
                _textLabel.textAlignment = NSTextAlignment.Center
                _textLabel.numberOfLines = 0
                _textLabel.frame = CGRectMake(20, 20, 200, 140)
                _noBookmarksScreen.addSubview(_textLabel)
            }
            
            if _settings.isOfflineMode {
                _textLabel.text = "No Offline\nBookmarks"
            } else {
                _textLabel.text = "No Saved\nBookmarks"
            }
            
            self.view.addSubview(_noBookmarksScreen)
            
        } else {
            if _headerView.subviews.count == 0 {
                _headerView.frame = CGRectMake(0, 0, 320, 50)
                _headerView.backgroundColor = UIColor(white:0.3, alpha:1.0)
                
                _bookmarkCountLabel.frame = CGRectMake(0, 0, 232, 50)
                _bookmarkCountLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleRightMargin]
                _bookmarkCountLabel.backgroundColor = UIColor.clearColor()
                _bookmarkCountLabel.textColor = UIColor.whiteColor()
                _bookmarkCountLabel.textAlignment = NSTextAlignment.Center
                _bookmarkCountLabel.font = ISMSBoldFont(22)
                _headerView.addSubview(_bookmarkCountLabel)
                
                _deleteBookmarksButton.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleRightMargin
                _deleteBookmarksButton.frame = CGRectMake(0, 0, 232, 50)
                _deleteBookmarksButton.addTarget(self, action:"_deleteBookmarksAction:", forControlEvents:UIControlEvents.TouchUpInside)
                _headerView.addSubview(_deleteBookmarksButton)
                
                _editBookmarksLabel.frame = CGRectMake(232, 0, 88, 50)
                _editBookmarksLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleLeftMargin]
                _editBookmarksLabel.backgroundColor = UIColor.clearColor()
                _editBookmarksLabel.textColor = UIColor.whiteColor()
                _editBookmarksLabel.textAlignment = NSTextAlignment.Center
                _editBookmarksLabel.font = ISMSBoldFont(22)
                _editBookmarksLabel.text = "Edit"
                _headerView.addSubview(_editBookmarksLabel)
                
                _editBookmarksButton.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleLeftMargin
                _editBookmarksButton.frame = CGRectMake(232, 0, 88, 40)
                _editBookmarksButton.addTarget(self, action:"_editBookmarksAction:", forControlEvents:UIControlEvents.TouchUpInside)
                _headerView.addSubview(_editBookmarksButton)
                
                _deleteBookmarksLabel.frame = CGRectMake(0, 0, 232, 50)
                _deleteBookmarksLabel.autoresizingMask = [UIViewAutoresizing.FlexibleWidth, UIViewAutoresizing.FlexibleRightMargin]
                _deleteBookmarksLabel.backgroundColor = UIColor(red:1, green:0, blue:0, alpha:0.5)
                _deleteBookmarksLabel.textColor = UIColor.whiteColor()
                _deleteBookmarksLabel.textAlignment = NSTextAlignment.Center
                _deleteBookmarksLabel.font = ISMSBoldFont(22)
                _deleteBookmarksLabel.adjustsFontSizeToFitWidth = true
                _deleteBookmarksLabel.minimumScaleFactor = 12.0 / _deleteBookmarksLabel.font.pointSize
                _deleteBookmarksLabel.text = "Remove # Bookmarks"
                _deleteBookmarksLabel.hidden = true
                _headerView.addSubview(_deleteBookmarksLabel)
            }
            
            _bookmarkCountLabel.text = bookmarksCount == 1 ? "1 Bookmark" : "\(bookmarksCount) Bookmarks"
            
            self.tableView.tableHeaderView = _headerView
        }
        
        _loadBookmarkIds()
        
        self.tableView.reloadData()
        
        Flurry.logEvent("BookmarksTab")
    }
    
    public override func viewWillDisappear(animated: Bool) {
        _bookmarkIds.removeAll()
    }
    
    private func _loadBookmarkIds() {
        var bookmarkIdsTemp = [Int]()
        _database.bookmarksDbQueue.inDatabase({ (db: FMDatabase!) in
            let query = "SELECT bookmarkId FROM bookmarks"
            let result = db.executeQuery(query, withArgumentsInArray: [])
            while result.next() {
                autoreleasepool {
                    if let bookmarkId = result.objectForColumnIndex(0) as? Int {
                        bookmarkIdsTemp.append(bookmarkId)
                    }
                }
            }
            result.close()
        })
        
        _bookmarkIds = bookmarkIdsTemp
    }
    
    private func _stringForCount(count: Int) -> String {
        switch count {
            case 0:
                return "Clear Bookmarks"
            case 1:
                return "Remove 1 Bookmark"
            default:
                return "Remove \(count) Bookmarks"
        }
    }
    
    private func _showDeleteButton() {
        _deleteBookmarksLabel.text = _stringForCount(_multiDeleteList.count)
        _bookmarkCountLabel.hidden = true
        _deleteBookmarksLabel.hidden = false
    }
    
    private func _hideDeleteButton() {
        _deleteBookmarksLabel.text = _stringForCount(_multiDeleteList.count)
        
        if _multiDeleteList.count == 0 && !self.tableView.editing {
            _bookmarkCountLabel.hidden = false
            _deleteBookmarksLabel.hidden = true
        } else {
            _deleteBookmarksLabel.text = "Clear Bookmarks"
        }
    }
    
    public func _editBookmarksAction(sender: AnyObject?) {
        if self.tableView.editing {
            NSNotificationCenter.defaultCenter().removeObserver(self, name:ISMSNotification_ShowDeleteButton, object:nil)
            NSNotificationCenter.defaultCenter().removeObserver(self, name:ISMSNotification_HideDeleteButton, object:nil)
            _multiDeleteList.removeAll()
            self.tableView.setEditing(false, animated:true)
            _hideDeleteButton()
            _editBookmarksLabel.backgroundColor = UIColor.clearColor()
            _editBookmarksLabel.text = "Edit"
            
            self.hideDeleteToggles()
            
            // Reload the table
            self.viewWillAppear(false)
        } else {
            NSNotificationCenter.defaultCenter().addObserver(self, selector:"_showDeleteButton", name:ISMSNotification_ShowDeleteButton, object:nil)
            NSNotificationCenter.defaultCenter().addObserver(self, selector:"_hideDeleteButton", name:ISMSNotification_HideDeleteButton, object:nil)
            _multiDeleteList.removeAll()
            self.tableView.setEditing(true, animated:true)
            _editBookmarksLabel.backgroundColor = UIColor(red:0.008, green:0.46, blue:0.933, alpha:1)
            _editBookmarksLabel.text = "Done"
            _showDeleteButton()
            
            self.showDeleteToggles()
        }
    }
    
    public func _deleteBookmarksAction(sender: AnyObject?) {
        // TODO: Don't use a string check for this, tisk tisk
        if _deleteBookmarksLabel.text == "Clear Bookmarks" {
            _database.bookmarksDbQueue.inDatabase({ (db: FMDatabase!) in
                db.executeUpdate("DROP TABLE IF EXISTS bookmarks", withArgumentsInArray:[])
                db.executeUpdate("CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, \(ISMSSong.standardSongColumnSchema()), bytes INTEGER)", withArgumentsInArray:[])
                db.executeUpdate("CREATE INDEX songId ON bookmarks (songId)", withArgumentsInArray:[])
            })
            
            _editBookmarksAction(nil)
            
            // Reload table data
            // TODO: Stop calling view delegate methods directly
            self.viewWillAppear(false)
        } else {
            var indexPaths = [AnyObject]()
            for index in _multiDeleteList {
                indexPaths.append(NSIndexPath(forRow:index, inSection:0))
                
                let bookmarkId = _bookmarkIds[index]
                _database.bookmarksDbQueue.inDatabase({ (db: FMDatabase!) in
                    db.executeUpdate("DELETE FROM bookmarks WHERE bookmarkId = ?", withArgumentsInArray:[bookmarkId])
                    return
                })
            }
            
            _loadBookmarkIds()
            
            self.tableView.deleteRowsAtIndexPaths(indexPaths, withRowAnimation:UITableViewRowAnimation.Automatic)
            
            _editBookmarksAction(nil)
        }
    }
}

extension BookmarksViewController: UITableViewDelegate, UITableViewDataSource {
    
    /*public override func tableView(tableView: UITableView, moveRowAtIndexPath sourceIndexPath: NSIndexPath, toIndexPath destinationIndexPath: NSIndexPath) {
        // Move the bookmark
        _database.bookmarksDbQueue.inDatabase({ (db: FMDatabase!) in
            let fromRow = sourceIndexPath.row + 1
            let toRow = destinationIndexPath.row + 1
            
            db.executeUpdate("DROP TABLE bookmarksTemp", withArgumentsInArray:[])
            db.executeUpdate("CREATE TABLE bookmarks (bookmarkId INTEGER PRIMARY KEY, playlistIndex INTEGER, name TEXT, position INTEGER, \(ISMSSong.standardSongColumnSchema()), bytes INTEGER)", withArgumentsInArray:[])
            
            if fromRow < toRow {
                db.executeUpdate("INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", withArgumentsInArray:[fromRow])
                db.executeUpdate("INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ? AND ROWID <= ?", withArgumentsInArray:[fromRow, toRow])
                db.executeUpdate("INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", withArgumentsInArray:[fromRow])
                db.executeUpdate("INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", withArgumentsInArray:[toRow])
                
                db.executeUpdate("DROP TABLE bookmarks", withArgumentsInArray:[])
                db.executeUpdate("ALTER TABLE bookmarksTemp RENAME TO bookmarks", withArgumentsInArray:[])
                db.executeUpdate("CREATE INDEX songId ON bookmarks (songId)", withArgumentsInArray:[])
            } else {
                db.executeUpdate("INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID < ?", withArgumentsInArray:[toRow])
                db.executeUpdate("INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID = ?", withArgumentsInArray:[fromRow])
                db.executeUpdate("INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID >= ? AND ROWID < ?", withArgumentsInArray:[toRow, fromRow])
                db.executeUpdate("INSERT INTO bookmarksTemp SELECT * FROM bookmarks WHERE ROWID > ?", withArgumentsInArray:[fromRow])
                
                db.executeUpdate("DROP TABLE bookmarks", withArgumentsInArray:[])
                db.executeUpdate("ALTER TABLE bookmarksTemp RENAME TO bookmarks", withArgumentsInArray:[])
                db.executeUpdate("CREATE INDEX songId ON bookmarks (songId)", withArgumentsInArray:[])
            }
        })
        
        // Fix the multiDeleteList to reflect the new row positions
        if _multiDeleteList.count > 0 {
            let fromRow = sourceIndexPath.row
            let toRow = destinationIndexPath.row
            
            var tempMultiDeleteList = [Int]()
            var newPosition: Int = 0
            for position in _multiDeleteList {
                if fromRow > toRow {
                    if position >= toRow && position <= fromRow {
                        if position == fromRow {
                            tempMultiDeleteList.append(toRow)
                        } else {
                            newPosition = position + 1
                            tempMultiDeleteList.append(newPosition)
                        }
                    } else {
                        tempMultiDeleteList.append(position)
                    }
                } else {
                    if position <= toRow && position >= fromRow {
                        if position == fromRow {
                            tempMultiDeleteList.append(toRow)
                        } else  {
                            newPosition = position - 1
                            tempMultiDeleteList.append(newPosition)
                        }
                    } else {
                        tempMultiDeleteList.append(position)
                    }
                }
            }
            _multiDeleteList = tempMultiDeleteList
        }
    }
    
    public override func tableView(tableView: UITableView, canMoveRowAtIndexPath indexPath: NSIndexPath) -> Bool {
        return true
    }*/
    
    public override func tableView(tableView: UITableView, editingStyleForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCellEditingStyle {
        return UITableViewCellEditingStyle.None
    }
    
    public override func numberOfSectionsInTableView(tableView: UITableView) -> Int {
        return 1
    }
    
    public override func tableView(tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return _bookmarkIds.count
    }
    
    public override func tableView(tableView: UITableView, cellForRowAtIndexPath indexPath: NSIndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCellWithIdentifier(_reuseIdentifier, forIndexPath:indexPath) as! CustomUITableViewCell
        cell.selectionStyle = UITableViewCellSelectionStyle.None
        cell.overlayDisabled = true
        cell.indexPath = indexPath
        
        cell.markedForDelete = contains(_multiDeleteList, indexPath.row)
        
        // Set up the cell...
        var song: ISMSSong? = nil
        var name: String? = nil
        var position: Double? = nil
        _database.bookmarksDbQueue.inDatabase({ (db: FMDatabase!) in
            let bookmarkId = self._bookmarkIds[indexPath.row]
            let result = db.executeQuery("SELECT * FROM bookmarks WHERE bookmarkId = ?", withArgumentsInArray:[bookmarkId])
            song = ISMSSong(fromDbResult:result)
            name = result.stringForColumn("name")
            position = result.doubleForColumn("position")
            result.close()
        })
        
        cell.coverArtId = song!.coverArtId
        
        cell.headerTitle = "\(name!) - \(NSString.formatTime(position!))"
        
        cell.title = song!.title
        cell.subTitle = song!.albumName == nil ? song!.artistName : "\(song!.artistName) - \(song!.albumName)"
        
        return cell
    }
    
    public override func tableView(tableView: UITableView, didSelectRowAtIndexPath indexPath: NSIndexPath) {
        if _settings.isJukeboxEnabled {
            _database.resetJukeboxPlaylist()
            _jukebox.jukeboxClearRemotePlaylist()
        } else {
            _database.resetCurrentPlaylistDb()
        }
        _playlist.isShuffle = false
        
        let bookmarkId = self._bookmarkIds[indexPath.row]
        var playlistIndex = 0
        var offsetSeconds = 0
        var offsetBytes = 0
        var song: ISMSSong? = nil
        
        _database.bookmarksDbQueue.inDatabase({ (db: FMDatabase!) in
            let result = db.executeQuery("SELECT * FROM bookmarks WHERE bookmarkId = ?", withArgumentsInArray:[bookmarkId])
            song = ISMSSong(fromDbResult: result)
            playlistIndex = Int(result.intForColumn("playlistIndex"))
            offsetSeconds = Int(result.intForColumn("position"))
            offsetBytes = Int(result.intForColumn("bytes"))
            result.close()
        })
        
        // See if there's a playlist table for this bookmark
        if _database.bookmarksDbQueue.tableExists("bookmark\(bookmarkId)") {
            // Save the playlist
            let databaseName = _settings.isOfflineMode ? "offlineCurrentPlaylist.db" : "\(_settings.urlString.md5())currentPlaylist.db"
            let currTable = _settings.isJukeboxEnabled ? "jukeboxCurrentPlaylist" : "currentPlaylist"
            let shufTable = _settings.isJukeboxEnabled ? "jukeboxShufflePlaylist" : "shufflePlaylist"
            let table = _playlist.isShuffle ? shufTable : currTable
            
            _database.bookmarksDbQueue.inDatabase({ (db: FMDatabase!) in
                let database = self._database.databaseFolderPath + "/" + databaseName
                db.executeUpdate("ATTACH DATABASE ? AS ?", withArgumentsInArray:[database, "currentPlaylistDb"])
                db.executeUpdate("INSERT INTO currentPlaylistDb.\(table) SELECT * FROM bookmark\(bookmarkId)", withArgumentsInArray:[])
                db.executeUpdate("DETACH DATABASE currentPlaylistDb", withArgumentsInArray:[])
            })
            
            if _settings.isJukeboxEnabled {
                _jukebox.jukeboxReplacePlaylistWithLocal()
            }
        } else {
            song?.addToCurrentPlaylistDbQueue()
        }
        
        _playlist.currentIndex = playlistIndex
        
        NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_CurrentPlaylistSongsQueued)
        
        self.showPlayer()
        
        // Check if these are old bookmarks and don't have byteOffset saved
        if offsetBytes == 0 && offsetSeconds != 0 {
            // By default, use the server reported bitrate
            var bitrate = Int(song!.bitRate)
            
            if song!.transcodedSuffix != nil {
                // This is a transcode, guess the bitrate and byteoffset
                let maxBitrate = _settings.currentMaxBitrate == 0 ? 128 : _settings.currentMaxBitrate
                bitrate = maxBitrate < bitrate ? maxBitrate : bitrate
            }
            
            // Use the bitrate to get byteoffset
            offsetBytes = BytesForSecondsAtBitrate(offsetSeconds, bitrate)
        }
        
        if _settings.isJukeboxEnabled {
            _music.playSongAtPosition(playlistIndex)
        } else {
            _music.startSongAtOffsetInBytes(UInt64(offsetBytes), andSeconds:Double(offsetSeconds))
        }
    }
}
