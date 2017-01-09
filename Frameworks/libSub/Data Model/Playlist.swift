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
        var maxId = 0
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT MAX(songIndex) FROM \(self.tableName)"
            maxId = db.longForQuery(query)
        }

        return maxId
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
                let query = "SELECT songId, serverId FROM \(self.tableName)"
                let result = try db.executeQuery(query)
                while result.next() {
                    let songId = result.long(forColumnIndex: 0)
                    let serverId = result.long(forColumnIndex: 1)
                    if let song = ISMSSong(itemId: songId, serverId: serverId) {
                        songs.append(song)
                    }
                }
            } catch {
                printError(error)
            }
        }
        
        return songs;
    }
    
    open func contains(song: ISMSSong) -> Bool {
        if let songId = song.songId as? Int, let serverId = song.serverId as? Int {
            return contains(songId: songId, serverId: serverId)
        }
        return false
    }
    
    open func contains(songId: Int, serverId: Int) -> Bool {
        var count = 0
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT COUNT(*) FROM \(self.tableName) WHERE songId = ? AND serverId = ?"
            count = db.longForQuery(query, songId, serverId)
        }
        return count > 0
    }
    
    open func indexOf(songId: Int, serverId: Int) -> Int? {
        var index: Int?
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT songIndex FROM \(self.tableName) WHERE songId = ? AND serverId = ?"
            index = db.longOptionalForQuery(query, songId, serverId)
        }
        
        if let index = index {
            return index - 1
        }
        return nil
    }
    
    open func song(atIndex index: Int) -> ISMSSong? {
        guard index >= 0 else {
            return nil
        }
        
        var songId: Int?
        var serverId: Int?
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT songId, serverId FROM \(self.tableName) WHERE songIndex = ?"
            do {
                let result = try db.executeQuery(query, index + 1)
                if result.next() {
                    songId = result.long(forColumnIndex: 0)
                    serverId = result.long(forColumnIndex: 1)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        if let songId = songId, let serverId = serverId {
            return ISMSSong(itemId: songId, serverId: serverId)
        } else {
            return nil
        }
    }
    
    open func add(song: ISMSSong, notify: Bool = false) {
        if let songId = song.songId as? Int, let serverId = song.serverId as? Int {
            add(songId: songId, serverId: serverId, notify: notify)
        }
    }
    
    open func add(songId: Int, serverId: Int, notify: Bool = false) {
        let query = "INSERT INTO \(self.tableName) (songId, serverId) VALUES (?, ?)"
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                try db.executeUpdate(query, songId, serverId)
            } catch {
                printError(error)
            }
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func add(songs: [ISMSSong], notify: Bool = false) {
        for song in songs {
            add(song: song, notify: false)
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func insert(song: ISMSSong, index: Int, notify: Bool = false) {
        if let songId = song.songId as? Int, let serverId = song.serverId as? Int {
            insert(songId: songId, serverId: serverId, index: index, notify: notify)
        }
    }
    
    open func insert(songId: Int, serverId: Int, index: Int, notify: Bool = false) {
        // TODO: See if this can be simplified by using sort by
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let query1 = "UPDATE \(self.tableName) SET songIndex = -songIndex WHERE songIndex >= ?"
                try db.executeUpdate(query1, index + 1)
                
                let query2 = "INSERT INTO \(self.tableName) VALUES (?, ?, ?)"
                try db.executeUpdate(query2, index + 1, songId, serverId)
                
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
    
    open func remove(songAtIndex index: Int, notify: Bool = false) {
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let query1 = "DELETE FROM \(self.tableName) WHERE songIndex = ?"
                try db.executeUpdate(query1, index + 1)

                let query2 = "UPDATE \(self.tableName) SET songIndex = songIndex - 1 WHERE songIndex > ?"
                try db.executeUpdate(query2, index + 1)
            } catch {
                printError(error)
            }
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func remove(songsAtIndexes indexes: IndexSet, notify: Bool = false) {
        // TODO: Improve performance
        for index in indexes {
            remove(songAtIndex: index, notify: false)
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    open func remove(song: ISMSSong, notify: Bool = false) {
        if let songId = song.songId as? Int, let serverId = song.serverId as? Int {
            remove(songId: songId, serverId: serverId, notify: notify)
        }
    }
    
    open func remove(songId: Int, serverId: Int, notify: Bool = false) {
        if let index = indexOf(songId: songId, serverId: serverId) {
            remove(songAtIndex: index + 1, notify: notify)
        }
    }
    
    open func remove(songs: [ISMSSong], notify: Bool = false) {
        for song in songs {
            remove(song: song, notify: false)
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
        if fromIndex != toIndex, let song = song(atIndex: fromIndex) {
            let finalToIndex = fromIndex < toIndex ? toIndex - 1 : toIndex
            if finalToIndex >= 0 && finalToIndex < songCount {
                remove(songAtIndex: fromIndex, notify: false)
                insert(song: song, index: finalToIndex, notify: notify)
                return true
            }
        }
        
        return false
    }
    
    // MARK: - Create new DB tables -
    
    fileprivate static func createTable(db: FMDatabase, name: String, playlistId: Int, serverId: Int) -> Bool {
        do {
            let table = Playlist.tableName(playlistId, serverId: serverId)
            try db.executeUpdate("INSERT INTO playlists VALUES (?, ?, ?)", playlistId, serverId, name)
            try db.executeUpdate("CREATE TABLE \(table) (songIndex INTEGER PRIMARY KEY AUTOINCREMENT, songId INTEGER, serverId INTEGER)")
            try db.executeUpdate("CREATE INDEX \(table)_songIdServerId ON \(table) (songId, serverId)")
        } catch {
            printError(error)
            return false
        }
        
        return true
    }

    open static func createPlaylist(_ name: String, serverId: Int) -> Playlist? {
        var playlistId: Int?
        
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            // Find the first available playlist id. Local playlists (before being synced) start from NSIntegerMax and count down.
            // So since NSIntegerMax is so huge, look for the lowest ID above NSIntegerMax - 1,000,000 to give room for virtually
            // unlimited local playlists without ever hitting the server playlists which start from 0 and go up.
            let lastPlaylistId = db.longForQuery("SELECT playlistId FROM playlists WHERE playlistId > ? AND serverId = ?", NSIntegerMax - 1000000, serverId)

            // Next available ID
            playlistId = lastPlaylistId - 1
            if !createTable(db: db, name: name, playlistId: playlistId!, serverId: serverId) {
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
            let query = "SELECT COUNT(*) FROM playlists WHERE playlistId = ? AND serverId = ?"
            let exists = db.longForQuery(query, playlistId, serverId) > 0
            if !exists {
                if !createTable(db: db, name: name, playlistId: playlistId, serverId: serverId) {
                    success = false
                }
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
