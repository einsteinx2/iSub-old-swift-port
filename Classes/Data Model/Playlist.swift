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

@objc class Playlist: NSObject, PersistedItem {
    
    // MARK: - Notifications -
    
    struct Notifications {
        static let playlistChanged = "playlistChanged"
        static let playlistIdKey   = "playlistIdKey"
    }
    
    func notifyPlaylistChanged() {
        NotificationCenter.postNotificationToMainThread(withName: Playlist.Notifications.playlistChanged,
                                                                  object: nil,
                                                                  userInfo: [Notifications.playlistIdKey: self.playlistId])
    }
    
    // MARK: - Class -
    
    var playlistId: Int64
    var playlistServerId: Int64 // This will just be serverId once ISMSPersistedModel is swift
    var name: String
    
    var songCount: Int {
        // SELECT COUNT(*) is O(n) while selecting the max rowId is O(1)
        // Since songIndex is our primary key field, it's an alias
        // for rowId. So SELECT MAX instead of SELECT COUNT here.
        var maxId = 0
        DatabaseSingleton.si.read.inDatabase { db in
            let query = "SELECT MAX(songIndex) FROM \(self.tableName)"
            maxId = db.intForQuery(query)
        }

        return maxId
    }
    
    // Special Playlists
    static let playQueuePlaylistId       = Int64.max - 1
    static let downloadQueuePlaylistId   = Int64.max - 2
    static let downloadedSongsPlaylistId = Int64.max - 3
    
    static var playQueue: Playlist {
        return Playlist(itemId: playQueuePlaylistId, serverId: SavedSettings.si().currentServerId)!
    }
    static var downloadQueue: Playlist {
        return Playlist(itemId: downloadQueuePlaylistId, serverId: SavedSettings.si().currentServerId)!
    }
    static var downloadedSongs: Playlist {
        return Playlist(itemId: downloadedSongsPlaylistId, serverId: SavedSettings.si().currentServerId)!
    }
    
    required init?(itemId: Int64, serverId: Int64) {
        var name: String?
        DatabaseSingleton.si.read.inDatabase { db in
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
        } else {
            return nil
        }
    }
    
    init(rxmlElement element: RXMLElement, serverId: Int64) {
        let playlistIdString = element.attribute("id") ?? ""
        self.playlistId = Int64(playlistIdString) ?? -1
        self.playlistServerId = serverId
        self.name = element.attribute("name") ?? ""
    }

    init(_ result: FMResultSet) {
        self.playlistId = result.longLongInt(forColumnIndex: 0)
        self.playlistServerId = result.longLongInt(forColumnIndex: 1)
        self.name = result.string(forColumnIndex: 2)
    }
    
    init(playlistId: Int64, serverId: Int64, name: String) {
        self.playlistId = playlistId
        self.playlistServerId = serverId
        self.name = name
    }
    
    func compare(_ otherObject: Playlist) -> ComparisonResult {
        return self.name.caseInsensitiveCompare(otherObject.name)
    }
    
    fileprivate static func tableName(_ playlistId: Int64, serverId: Int64) -> String {
        return "playlist\(playlistId)_server\(serverId)"
    }
    
    fileprivate var tableName: String {
        return Playlist.tableName(self.playlistId, serverId: self.playlistServerId)
    }
    
    var songs: [Song] {
        var songs = [Song]()
        
        DatabaseSingleton.si.read.inDatabase { db in
            do {
                let query = "SELECT songId, serverId FROM \(self.tableName)"
                let result = try db.executeQuery(query)
                while result.next() {
                    let songId = result.longLongInt(forColumnIndex: 0)
                    let serverId = result.longLongInt(forColumnIndex: 1)
                    if let song = SongRepository.si.song(songId: songId, serverId: serverId) {
                        songs.append(song)
                    }
                }
            } catch {
                printError(error)
            }
        }
        
        return songs;
    }
    
    func contains(song: Song) -> Bool {
        return contains(songId: song.songId, serverId: song.serverId)
    }
    
    func contains(songId: Int64, serverId: Int64) -> Bool {
        var count = 0
        DatabaseSingleton.si.read.inDatabase { db in
            let query = "SELECT COUNT(*) FROM \(self.tableName) WHERE songId = ? AND serverId = ?"
            count = db.intForQuery(query, songId, serverId)
        }
        return count > 0
    }
    
    func indexOf(songId: Int64, serverId: Int64) -> Int? {
        var index: Int?
        DatabaseSingleton.si.read.inDatabase { db in
            let query = "SELECT songIndex FROM \(self.tableName) WHERE songId = ? AND serverId = ?"
            index = db.intOptionalForQuery(query, songId, serverId)
        }
        
        if let index = index {
            return index - 1
        }
        return nil
    }
    
    func song(atIndex index: Int) -> Song? {
        guard index >= 0 else {
            return nil
        }
        
        var songId: Int64?
        var serverId: Int64?
        DatabaseSingleton.si.read.inDatabase { db in
            let query = "SELECT songId, serverId FROM \(self.tableName) WHERE songIndex = ?"
            do {
                let result = try db.executeQuery(query, index + 1)
                if result.next() {
                    songId = result.longLongInt(forColumnIndex: 0)
                    serverId = result.longLongInt(forColumnIndex: 1)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        if let songId = songId, let serverId = serverId {
            return SongRepository.si.song(songId: songId, serverId: serverId)
        } else {
            return nil
        }
    }
    
    func add(song: Song, notify: Bool = false) {
        add(songId: song.songId, serverId: song.serverId, notify: notify)
    }
    
    func add(songId: Int64, serverId: Int64, notify: Bool = false) {
        let query = "INSERT INTO \(self.tableName) (songId, serverId) VALUES (?, ?)"
        DatabaseSingleton.si.write.inDatabase { db in
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
    
    func add(songs: [Song], notify: Bool = false) {
        for song in songs {
            add(song: song, notify: false)
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    func insert(song: Song, index: Int, notify: Bool = false) {
        insert(songId: song.songId, serverId: song.serverId, index: index, notify: notify)
    }
    
    func insert(songId: Int64, serverId: Int64, index: Int, notify: Bool = false) {
        // TODO: See if this can be simplified by using sort by
        DatabaseSingleton.si.write.inDatabase { db in
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
    
    func remove(songAtIndex index: Int, notify: Bool = false) {
        DatabaseSingleton.si.write.inDatabase { db in
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
    
    func remove(songsAtIndexes indexes: IndexSet, notify: Bool = false) {
        // TODO: Improve performance
        for index in indexes {
            remove(songAtIndex: index, notify: false)
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    func remove(song: Song, notify: Bool = false) {
        remove(songId: song.songId, serverId: song.serverId, notify: notify)
    }
    
    func remove(songId: Int64, serverId: Int64, notify: Bool = false) {
        if let index = indexOf(songId: songId, serverId: serverId) {
            remove(songAtIndex: index + 1, notify: notify)
        }
    }
    
    func remove(songs: [Song], notify: Bool = false) {
        for song in songs {
            remove(song: song, notify: false)
        }
        
        if notify {
            notifyPlaylistChanged()
        }
    }
    
    func removeAllSongs(_ notify: Bool = false) {
        DatabaseSingleton.si.write.inDatabase { db in
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
    
    func moveSong(fromIndex: Int, toIndex: Int, notify: Bool = false) -> Bool {
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
    
    fileprivate static func createTable(db: FMDatabase, name: String, playlistId: Int64, serverId: Int64) -> Bool {
        do {
            let table = Playlist.tableName(playlistId, serverId: serverId)
            try db.executeUpdate("INSERT INTO playlists VALUES (?, ?, ?)", playlistId, serverId, name)
            try db.executeUpdate("CREATE TABLE \(table) (songIndex INTEGER PRIMARY KEY, songId INTEGER, serverId INTEGER)")
            try db.executeUpdate("CREATE INDEX \(table)_songIdServerId ON \(table) (songId, serverId)")
        } catch {
            printError(error)
            return false
        }
        
        return true
    }

    static func createPlaylist(_ name: String, serverId: Int64) -> Playlist? {
        var playlistId: Int64?
        
        DatabaseSingleton.si.write.inDatabase { db in
            // Find the first available playlist id. Local playlists (before being synced) start from NSIntegerMax and count down.
            // So since NSIntegerMax is so huge, look for the lowest ID above NSIntegerMax - 1,000,000 to give room for virtually
            // unlimited local playlists without ever hitting the server playlists which start from 0 and go up.
            let lastPlaylistId = db.int64ForQuery("SELECT playlistId FROM playlists WHERE playlistId > ? AND serverId = ?", Int64.max - 1000000, serverId)

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
    
    static func createPlaylist(_ name: String, playlistId: Int64, serverId: Int64) -> Playlist? {
        var success = true
        DatabaseSingleton.si.write.inDatabase { db in
            let query = "SELECT COUNT(*) FROM playlists WHERE playlistId = ? AND serverId = ?"
            let exists = db.intForQuery(query, playlistId, serverId) > 0
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
    
    var itemId: Int64 {
        return playlistId
    }
    
    var serverId: Int64 {
        return playlistServerId
    }
    
    var itemName: String {
        return name
    }
    
    // MARK: - PersistantItem -
    
    required init(result: FMResultSet, repository: ItemRepository) {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    static func item(itemId: Int64, serverId: Int64, repository: ItemRepository) -> Item? {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    var hasCachedSubItems: Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    var isPersisted: Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    func insert() -> Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    func replace() -> Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    func cache() -> Bool {
        // Not supported
        fatalError("not supported")
    }
    
    func delete() -> Bool {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    func deleteCache() -> Bool {
        // Not supported
        fatalError("not supported")
    }
    
    func loadSubItems() {
        // TODO: Fill this in
        fatalError("not implemented yet")
    }
    
    static func ==(lhs: Playlist, rhs: Playlist) -> Bool {
        return lhs.playlistId == rhs.playlistId
    }
}
