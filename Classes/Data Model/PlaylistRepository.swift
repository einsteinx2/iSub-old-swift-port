//
//  PlaylistRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct PlaylistRepository: ItemRepository {
    static let si = PlaylistRepository()
    fileprivate let gr = GenericItemRepository.si
    
    let table = "playlists"
    let cachedTable = "playlists"
    let itemIdField = "playlistId"
    
    fileprivate func playlistTableName(playlistId: Int64, serverId: Int64) -> String {
        return "playlist\(playlistId)_server\(serverId)"
    }
    
    func playlist(playlistId: Int64, serverId: Int64, loadSubItems: Bool = false) -> Playlist? {
        return gr.item(repository: self, itemId: playlistId, serverId: serverId, loadSubItems: loadSubItems)
    }
    
    func allPlaylists(serverId: Int64? = nil, isCachedTable: Bool = false) -> [Playlist] {
        let playlists: [Playlist] = gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable)
        let excludedIds = [Playlist.playQueuePlaylistId, Playlist.downloadQueuePlaylistId, Playlist.downloadedSongsPlaylistId]
        return playlists.filter({!excludedIds.contains($0.playlistId)})        
    }
    
    func isPersisted(playlist: Playlist, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, item: playlist, isCachedTable: isCachedTable)
    }
    
    func isPersisted(playlistId: Int64, serverId: Int64, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, itemId: playlistId, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func delete(playlist: Playlist, isCachedTable: Bool = false) -> Bool {
        return gr.delete(repository: self, item: playlist, isCachedTable: isCachedTable)
    }
    
    func replace(playlist: Playlist, isCachedTable: Bool = false) -> Bool {
        var success = true
        Database.si.write.inDatabase { db in
            do {
                let query = "REPLACE INTO \(self.table) VALUES (?, ?, ?, ?)"
                try db.executeUpdate(query, playlist.playlistId, playlist.serverId, playlist.name, n2N(playlist.coverArtId))
                try self.createPlaylistTable(db: db, playlistId: playlist.playlistId, serverId: playlist.serverId, name: playlist.name)
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func hasCachedSubItems(playlist: Playlist) -> Bool {
        let tableName = playlistTableName(playlistId: playlist.playlistId, serverId: playlist.serverId)
        let query = "SELECT COUNT(*) FROM \(tableName) JOIN cachedSongs where \(tableName).songId = cachedSongs.songId"
        return Database.si.read.boolForQuery(query)
    }
    
    fileprivate func createPlaylistTable(db: FMDatabase, playlistId: Int64, serverId: Int64, name: String) throws {
        let table = playlistTableName(playlistId: playlistId, serverId: serverId)
        try db.executeUpdate("CREATE TABLE IF NOT EXISTS \(table) (songIndex INTEGER PRIMARY KEY, songId INTEGER, serverId INTEGER)")
        try db.executeUpdate("CREATE INDEX IF NOT EXISTS \(table)_songIdServerId ON \(table) (songId, serverId)")
    }
    
    func playlist(playlistId: Int64? = nil, name: String, serverId: Int64) -> Playlist {
        if let playlistId = playlistId {
            if let playlist = playlist(playlistId: playlistId, serverId: serverId) {
                return playlist
            }
            
            Database.si.write.inDatabase { db in
                try? db.executeUpdate("INSERT INTO playlists VALUES (?, ?, ?, ?)", playlistId, serverId, name, NSNull())
                try? self.createPlaylistTable(db: db, playlistId: playlistId, serverId: serverId, name: name)
            }
            
            return playlist(playlistId: playlistId, serverId: serverId)!
        } else {
            var newPlaylistId: Int64 = -1
            
            // Get the ID and create the playlist table in the same block to avoid threading issues
            Database.si.write.inDatabase { db in
                // Find the first available playlist id. Local playlists (before being synced) start from NSIntegerMax and count down.
                // So since NSIntegerMax is so huge, look for the lowest ID above NSIntegerMax - 1,000,000 to give room for virtually
                // unlimited local playlists without ever hitting the server playlists which start from 0 and go up.
                let lastPlaylistId = db.int64ForQuery("SELECT playlistId FROM playlists WHERE playlistId > ? AND serverId = ?", Int64.max - 1000000, serverId)
                
                // Next available ID
                newPlaylistId = lastPlaylistId - 1
                try? db.executeUpdate("INSERT INTO playlists VALUES (?, ?, ?, ?)", newPlaylistId, serverId, name, NSNull())
                try? self.createPlaylistTable(db: db, playlistId: newPlaylistId, serverId: serverId, name: name)
            }
            
            return playlist(playlistId: newPlaylistId, serverId: serverId)!
        }
    }
    
    func loadSubItems(playlist: Playlist) {
        var songs = [Song]()
        Database.si.read.inDatabase { db in
            do {
                let query = "SELECT songId, serverId FROM \(playlist.tableName)"
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
        playlist.songs = songs
    }
    
    func overwriteSubItems(playlist: Playlist) {
        Database.si.write.inDatabase { db in
            do {
                let query = "DELETE FROM \(playlist.tableName)"
                try db.executeUpdate(query)
            
                for song in playlist.songs {
                    let query = "INSERT INTO \(playlist.tableName) (songId, serverId) VALUES (?, ?)"
                    try db.executeUpdate(query, song.songId, song.serverId)
                }
            } catch {
                printError(error)
            }
        }
    }
    
    func createDefaultPlaylists(serverId: Int64) {
        _ = PlaylistRepository.si.playlist(playlistId: Playlist.playQueuePlaylistId, name: "Play Queue", serverId: serverId)
        _ = PlaylistRepository.si.playlist(playlistId: Playlist.downloadQueuePlaylistId, name: "Download Queue", serverId: serverId)
        _ = PlaylistRepository.si.playlist(playlistId: Playlist.downloadedSongsPlaylistId, name: "Downloaded Songs", serverId: serverId)
    }
}

extension Playlist {
    var tableName: String {
        return PlaylistRepository.si.playlistTableName(playlistId: playlistId, serverId: serverId)
    }
    
    var songCount: Int {
        // SELECT COUNT(*) is O(n) while selecting the max rowId is O(1)
        // Since songIndex is our primary key field, it's an alias
        // for rowId. So SELECT MAX instead of SELECT COUNT here.
        var maxId = 0
        Database.si.read.inDatabase { db in
            let query = "SELECT MAX(songIndex) FROM \(self.tableName)"
            maxId = db.intForQuery(query)
        }
        
        return maxId
    }
    
    func contains(song: Song) -> Bool {
        return contains(songId: song.songId, serverId: song.serverId)
    }
    
    func contains(songId: Int64, serverId: Int64) -> Bool {
        var count = 0
        Database.si.read.inDatabase { db in
            let query = "SELECT COUNT(*) FROM \(self.tableName) WHERE songId = ? AND serverId = ?"
            count = db.intForQuery(query, songId, serverId)
        }
        return count > 0
    }
    
    func indexOf(songId: Int64, serverId: Int64) -> Int? {
        var index: Int?
        Database.si.read.inDatabase { db in
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
        Database.si.read.inDatabase { db in
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
        Database.si.write.inDatabase { db in
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
        Database.si.write.inDatabase { db in
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
        Database.si.write.inDatabase { db in
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
        Database.si.write.inDatabase { db in
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
}

extension Playlist {
    static let playQueuePlaylistId       = Int64.max - 1
    static let downloadQueuePlaylistId   = Int64.max - 2
    static let downloadedSongsPlaylistId = Int64.max - 3
    
    static var playQueue: Playlist {
        return PlaylistRepository.si.playlist(playlistId: playQueuePlaylistId, serverId: SavedSettings.si.currentServerId)!
    }
    static var downloadQueue: Playlist {
        return PlaylistRepository.si.playlist(playlistId: downloadQueuePlaylistId, serverId: SavedSettings.si.currentServerId)!
    }
    static var downloadedSongs: Playlist {
        return PlaylistRepository.si.playlist(playlistId: downloadedSongsPlaylistId, serverId: SavedSettings.si.currentServerId)!
    }
}

extension Playlist: PersistedItem {
    class func item(itemId: Int64, serverId: Int64, repository: ItemRepository = AlbumRepository.si) -> Item? {
        return (repository as? AlbumRepository)?.album(albumId: itemId, serverId: serverId)
    }
    
    var isPersisted: Bool {
        return repository.isPersisted(playlist: self)
    }
    
    var hasCachedSubItems: Bool {
        return repository.hasCachedSubItems(playlist: self)
    }
    
    func replace() -> Bool {
        return repository.replace(playlist: self)
    }
    
    func cache() -> Bool {
        // Not implemented
        return false
    }
    
    func delete() -> Bool {
        return repository.delete(playlist: self)
    }
    
    func deleteCache() -> Bool {
        // Not implemented
        return false
    }
    
    func loadSubItems() {
        repository.loadSubItems(playlist: self)
    }
    
    func overwriteSubItems() {
        repository.overwriteSubItems(playlist: self)
    }
}
