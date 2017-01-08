//
//  Playlist.swift
//  LibSub
//
//  Created by Benjamin Baron on 2/10/16.
//
//

// Important note: Playlist table song indexes are 0 based to better interact with Swift/ObjC arrays.
// Normally SQLite table primary key fields start at 1 rather than 0. We force it to start at 0
// by inserting the first record with a manually chosen songIndex of 0.

import Foundation

@objc(ISMSPlaylist)
open class Playlist: NSObject, ISMSPersistedModel, NSCopying, NSCoding {
    
    // MARK: - Notifications -
    
    public struct Notifications {
        public static let playlistChanged = "playlistChanged"
        
        public static let playlistIdKey   = "playlistIdKey"
    }
    
    func notifyPlaylistChanged() {
        NotificationCenter.postNotificationToMainThread(withName: Playlist.Notifications.playlistChanged,
                                                                  object: nil,
                                                                  userInfo: [Notifications.playlistIdKey: self.playlistId])
    }
    
    // MARK: - Class -
    
    open var playlistId: Int
    open var playlistServerId: Int // This will just be serverId once ISMSPersistedModel is swift
    open var name: String
    
    open var songCount: Int {
        // SELECT COUNT(*) is O(n) while selecting the max rowId is O(1)
        // Since songIndex is our primary key field, it's an alias
        // for rowId. So SELECT MAX instead of SELECT COUNT here.
        var maxId: Int?
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT MAX(songIndex) FROM \(self.tableName)"
            maxId = db.longOptionalForQuery(query)
        }
        
        if let maxId = maxId {
            return maxId + 1
        }
        return 0
    }
    
    // Special Playlists
    open static let playQueuePlaylistId       = NSIntegerMax - 1
    open static let downloadQueuePlaylistId   = NSIntegerMax - 2
    open static let downloadedSongsPlaylistId = NSIntegerMax - 3
    
    open static var playQueue: Playlist {
        return Playlist(itemId: playQueuePlaylistId, serverId: SavedSettings.si().currentServerId)!
    }
    open static var downloadQueue: Playlist {
        return Playlist(itemId: downloadQueuePlaylistId, serverId: SavedSettings.si().currentServerId)!
    }
    open static var downloadedSongs: Playlist {
        return Playlist(itemId: downloadedSongsPlaylistId, serverId: SavedSettings.si().currentServerId)!
    }
    
    public required init?(itemId: Int, serverId: Int) {
        var name: String?
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT name FROM playlists WHERE playlistId = ? AND serverId = ?"
            do {
                let result = try db.executeQuery(query, itemId, serverId)
                if result.next() {
                    name = result.string(forColumnIndex: 0)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        if let name = name {
            self.playlistId = itemId
            self.playlistServerId = serverId
            self.name = name
            super.init()
        } else {
            self.playlistId = -1; self.playlistServerId = -1; self.name = ""
            super.init()
            return nil
        }
    }
    
    public init(rxmlElement element: RXMLElement, serverId: Int) {
        let playlistIdString = element.attribute("id") ?? ""
        self.playlistId = Int(playlistIdString) ?? -1
        self.playlistServerId = serverId
        self.name = element.attribute("name") ?? ""
        
        super.init()
    }

    public init(_ result: FMResultSet) {
        self.playlistId = result.long(forColumnIndex: 0)
        self.playlistServerId = result.long(forColumnIndex: 1)
        self.name = result.string(forColumnIndex: 2)
        
        super.init()
    }
    
    public init(playlistId: Int, serverId: Int, name: String) {
        self.playlistId = playlistId
        self.playlistServerId = serverId
        self.name = name
        
        super.init()
    }
    
    open func compare(_ otherObject: Playlist) -> ComparisonResult {
        return self.name.caseInsensitiveCompare(otherObject.name)
    }
    
    fileprivate static func tableName(_ playlistId: Int, serverId: Int) -> String {
        return "playlist\(playlistId)_server\(serverId)"
    }
    
    fileprivate var tableName: String {
        return Playlist.tableName(self.playlistId, serverId: self.playlistServerId)
    }
    
    open var songs: [ISMSSong] {
        var songs = [ISMSSong]()
        
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            do {
                let query = "SELECT songId FROM \(self.tableName)"
                let result = try db.executeQuery(query)
                while result.next() {
                    if let song = ISMSSong(itemId: result.long(forColumnIndex: 0), serverId: self.playlistServerId) {
                        songs.append(song)
                    }
                }
            } catch {
                printError(error)
            }
        }
        
        return songs;
    }
    
    open func containsSongId(_ songId: Int) -> Bool {
        var count = 0
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT COUNT(*) FROM \(self.tableName) WHERE songId = ?"
            count = db.longForQuery(query, songId)
        }
        return count > 0
    }
    
    open func indexOfSongId(_ songId: Int) -> Int? {
        var index: Int?
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT songIndex FROM \(self.tableName) WHERE songId = ?"
            index = db.longOptionalForQuery(query, songId)
        }
        return index
    }
    
    open func songAtIndex(_ index: Int) -> ISMSSong? {
        var songId: Int?
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT songId FROM \(self.tableName) WHERE songIndex = ?"
            songId = db.longOptionalForQuery(query, index)
        }
        
        if let songId = songId {
            return ISMSSong(itemId: songId, serverId: playlistServerId)
        } else {
            return nil
        }
    }
    
    open func addSong(song: ISMSSong, notify: Bool = false) {
        if let songId = song.songId?.intValue {
            addSong(songId: songId, notify: notify)
        }
    }
    
    open func addSong(songId: Int, notify: Bool = false) {
        var query = ""
        if self.songCount == 0 {
            // Force songIndex to start at 0
            query = "INSERT INTO \(self.tableName) VALUES (0, ?)"
        } else {
            query = "INSERT INTO \(self.tableName) (songId) VALUES (?)"
        }
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                try db.executeUpdate(query, songId)
            } catch {
                printError(error)
            }
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func addSongs(songs: [ISMSSong], notify: Bool = false) {
        var songIds = [Int]()
        for song in songs {
            if let songId = song.songId?.intValue {
                songIds.append(songId)
            }
        }
        
        addSongs(songIds: songIds, notify: notify)
    }
    
    open func addSongs(songIds: [Int], notify: Bool = false) {
        // TODO: Improve performance
        for songId in songIds {
            addSong(songId: songId)
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func insertSong(song: ISMSSong, index: Int, notify: Bool = false) {
        if let songId = song.songId?.intValue {
            insertSong(songId: songId, index: index, notify: notify)
        }
    }
    
    open func insertSong(songId: Int, index: Int, notify: Bool = false) {
        // TODO: See if this can be simplified by using sort by
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let query1 = "UPDATE \(self.tableName) SET songIndex = -songIndex WHERE songIndex >= ?"
                try db.executeUpdate(query1, index)
                
                let query2 = "INSERT INTO \(self.tableName) VALUES (?, ?)"
                try db.executeUpdate(query2, index, songId)
                
                let query3 = "UPDATE \(self.tableName) SET songIndex = (-songIndex) + 1 WHERE songIndex < 0"
                try db.executeUpdate(query3)
            } catch {
                printError(error)
            }
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func removeSongAtIndex(_ index: Int, notify: Bool = false) {
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let query1 = "DELETE FROM \(self.tableName) WHERE songIndex = ?"
                try db.executeUpdate(query1, index)

                let query2 = "UPDATE \(self.tableName) SET songIndex = songIndex - 1 WHERE songIndex > ?"
                try db.executeUpdate(query2, index)
            } catch {
                printError(error)
            }
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func removeSongsAtIndexes(_ indexes: IndexSet, notify: Bool = false) {
        // TODO: Improve performance
        for index in indexes {
            removeSongAtIndex(index, notify: false)
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func removeSong(song: ISMSSong, notify: Bool = false) {
        if let songId = song.songId?.intValue {
            removeSong(songId: songId, notify: notify)
        }
    }
    
    open func removeSong(songId: Int, notify: Bool = false) {
        if let index = indexOfSongId(songId) {
            removeSongAtIndex(index, notify: notify)
        }
    }
    
    open func removeSongs(songs: [ISMSSong], notify: Bool = false) {
        var songIds = [Int]()
        for song in songs {
            if let songId = song.songId?.intValue {
                songIds.append(songId)
            }
        }

        removeSongs(songIds: songIds, notify: notify)
    }
    
    open func removeSongs(songIds: [Int], notify: Bool = false) {
        // TODO: Improve performance
        for songId in songIds {
            removeSong(songId: songId, notify: false)
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func removeAllSongs(_ notify: Bool = false) {
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let query1 = "DELETE FROM \(self.tableName)"
                try db.executeUpdate(query1)
            } catch {
                printError(error)
            }
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func moveSong(fromIndex: Int, toIndex: Int, notify: Bool = false) -> Bool {
        if fromIndex != toIndex, let songId = songAtIndex(fromIndex)?.songId?.intValue {
            let finalToIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
            if finalToIndex >= 0 && finalToIndex < songCount {
                removeSongAtIndex(fromIndex, notify: false)
                insertSong(songId: songId, index: finalToIndex, notify: notify)
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Create new DB tables -
    
    open static func createPlaylist(_ name: String, serverId: Int) -> Playlist? {
        var playlistId: Int?
        
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            // Find the first available playlist id. Local playlists (before being synced) start from NSIntegerMax and count down.
            // So since NSIntegerMax is so huge, look for the lowest ID above NSIntegerMax - 1,000,000 to give room for virtually
            // unlimited local playlists without ever hitting the server playlists which start from 0 and go up.
            let lastPlaylistId = db.longForQuery("SELECT playlistId FROM playlists WHERE playlistId > ? AND serverId = ?", NSIntegerMax - 1000000, serverId)

            // Next available ID
            playlistId = lastPlaylistId - 1

            // Do the creation here instead of calling createPlaylistWithName:andId: so it's all in one transaction
            do {
                let table = Playlist.tableName(playlistId!, serverId: serverId)
                try db.executeUpdate("INSERT INTO playlists VALUES (?, ?, ?)", playlistId!, serverId, name)
                try db.executeUpdate("CREATE TABLE \(table) (songIndex INTEGER PRIMARY KEY AUTOINCREMENT, songId INTEGER)")
                try db.executeUpdate("CREATE INDEX \(table)_songId ON \(table) (songId)")
                
                // Force the auto_increment to start at 0
                try db.executeUpdate("INSERT INTO \(table) VALUES (-1, 0)", table)
                try db.executeUpdate("DELETE FROM \(table)")
                
            } catch {
                printError(error)
                playlistId = nil
            }
        }
        
        if let playlistId = playlistId {
            return Playlist(itemId: playlistId, serverId: serverId)
        } else {
            return nil
        }
    }
    
    open static func createPlaylist(_ name: String, playlistId: Int, serverId: Int) -> Playlist? {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let exists = db.longForQuery("SELECT COUNT(*) FROM playlists WHERE playlistId = ? AND serverId = ?", playlistId, serverId) > 0
                if !exists {
                    // Do the creation here instead of calling createPlaylistWithName:andId: so it's all in one transaction
                    let table = Playlist.tableName(playlistId, serverId: serverId)
                    try db.executeUpdate("INSERT INTO playlists VALUES (?, ?, ?)", playlistId, serverId, name)
                    try db.executeUpdate("CREATE TABLE \(table) (songIndex INTEGER PRIMARY KEY, songId INTEGER)")
                    try db.executeUpdate("CREATE INDEX \(table)_songId ON \(table) (songId)")
                }
            } catch {
                printError(error)
                success = false
            }
        }
        
        if success {
            return Playlist(itemId: playlistId, serverId: serverId)
        } else {
            return nil
        }
    }
    
    // MARK: - ISMSItem -
    
    open var itemId: NSNumber? {
        return NSNumber(value: self.playlistId as Int)
    }
    
    open var serverId: NSNumber? {
        return NSNumber(value: self.playlistServerId as Int)
    }
    
    open var itemName: String? {
        return self.name
    }
    
    // MARK: - ISMSPersistantItem -
    
    public var isPersisted: Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    open func insert() -> Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    open func replace() -> Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    open func cacheModel() -> Bool {
        // Not supported
        fatalError("not implemented yet")
    }
    
    open func delete() -> Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    open func reloadSubmodels() {
        // TODO: Fill this in
    }
    
    // MARK: - NSCoding -
    
    open func encode(with aCoder: NSCoder) {
        aCoder.encode(self.playlistId, forKey: "playlistId")
        aCoder.encode(self.playlistServerId, forKey: "serverId")
        aCoder.encode(self.name, forKey: "name")
    }
    
    public required init?(coder aDecoder: NSCoder) {
        self.playlistId = aDecoder.decodeInteger(forKey: "playlistId")
        self.playlistServerId = aDecoder.decodeInteger(forKey: "serverId")
        self.name       = aDecoder.decodeObject(forKey: "name") as! String
    }
    
    // MARK: - NSCopying -
    
    open func copy(with zone: NSZone?) -> Any {
        return Playlist(playlistId: self.playlistId, serverId: self.playlistServerId, name: self.name)
    }
    
    // MARK: - Equality -
    
    override open func isEqual(_ object: Any?) -> Bool {
        if let playlist = object as? Playlist {
            return self.playlistId == playlist.playlistId
        }
        return false
    }
}

func ==(lhs: Playlist, rhs: Playlist) -> Bool {
    return lhs.playlistId == rhs.playlistId
}
