//
//  SongRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct SongRepository: ItemRepository {
    static let si = SongRepository()
    fileprivate let gr = GenericItemRepository.si
    
    let table = "songs"
    let cachedTable = "cachedSongs"
    let itemIdField = "songId"
    
    func song(songId: Int64, serverId: Int64, loadSubItems: Bool = false) -> Song? {
        return gr.item(repository: self, itemId: songId, serverId: serverId, loadSubItems: loadSubItems)
    }
    
    func allSongs(serverId: Int64? = nil, isCachedTable: Bool = false) -> [Song] {
        return gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func deleteAllSongs(serverId: Int64?) -> Bool {
        return gr.deleteAllItems(repository: self, serverId: serverId)
    }
    
    func isPersisted(song: Song, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, item: song, isCachedTable: isCachedTable)
    }
    
    func isPersisted(songId: Int64, serverId: Int64, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, itemId: songId, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func hasCachedSubItems(song: Song) -> Bool {
        return gr.hasCachedSubItems(repository: self, item: song)
    }
    
    func delete(song: Song, isCachedTable: Bool = false) -> Bool {
        return gr.delete(repository: self, item: song, isCachedTable: isCachedTable)
    }
    
    func lastPlayed(songId: Int64, serverId: Int64, isCachedTable: Bool = false) -> Date? {
        var lastPlayed: Date? = nil
        DatabaseSingleton.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            let query = "SELECT lastPlayed FROM \(table) WHERE songId = ? AND serverId = ?"
            lastPlayed = db.dateForQuery(query, songId, serverId)
        }
        return lastPlayed
    }
    
    func deleteRootSongs(mediaFolderId: Int64?, serverId: Int64, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            var query = "DELETE FROM \(table) WHERE folderId IS NULL AND serverId = ?"
            do {
                if let mediaFolderId = mediaFolderId {
                    query += " AND mediaFolderId = ?"
                    try db.executeUpdate(query, serverId, mediaFolderId)
                } else {
                    try db.executeUpdate(query, serverId)
                }
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func rootSongs(mediaFolderId: Int64?, serverId: Int64, isCachedTable: Bool = false) -> [Song] {
        var songs = [Song]()
        DatabaseSingleton.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            var query = "SELECT * FROM \(table) WHERE folderId IS NULL AND serverId = ?"
            do {
                let result: FMResultSet
                if let mediaFolderId = mediaFolderId {
                    query += " AND mediaFolderId = ?"
                    result = try db.executeQuery(query, serverId, mediaFolderId)
                } else {
                    result = try db.executeQuery(query, serverId)
                }
                
                while result.next() {
                    let song = Song(result: result)
                    songs.append(song)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        return songs
    }
    
    func songs(albumId: Int64, serverId: Int64, isCachedTable: Bool = false) -> [Song] {
        var songs = [Song]()
        DatabaseSingleton.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            let query = "SELECT * FROM \(table) WHERE albumId = ? AND serverId = ?"
            do {
                let result = try db.executeQuery(query, albumId, serverId)
                while result.next() {
                    let song = Song(result: result)
                    songs.append(song)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        return songs
    }
    
    func songs(folderId: Int64, serverId: Int64, isCachedTable: Bool = false) -> [Song] {
        var songs = [Song]()
        DatabaseSingleton.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            let query = "SELECT * FROM \(table) WHERE folderId = ? AND serverId = ?"
            do {
                let result = try db.executeQuery(query, folderId, serverId)
                while result.next() {
                    let song = Song(result: result)
                    songs.append(song)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        return songs
    }
    
    func replace(song: Song, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si.write.inDatabase { db in
            do {
                let table = tableName(repository: self, isCachedTable: isCachedTable)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, song.songId, song.serverId, song.contentTypeId, n2N(song.transcodedContentTypeId), n2N(song.mediaFolderId), n2N(song.folderId), n2N(song.artistId), n2N(song.albumId), n2N(song.genreId), n2N(song.coverArtId), song.title, n2N(song.duration), n2N(song.bitrate), n2N(song.trackNumber), n2N(song.discNumber), n2N(song.year), song.size, song.path, n2N(song.lastPlayed), n2N(song.artistName), n2N(song.albumName))
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func loadSubItems(song: Song) {
        if let folderId = song.folderId {
            song.folder = FolderRepository.si.folder(folderId: folderId, serverId: song.serverId)
        }
        
        if let artistId = song.artistId {
            song.artist = ArtistRepository.si.artist(artistId: artistId, serverId: song.serverId)
        }
        
        if let albumId = song.albumId {
            song.album = AlbumRepository.si.album(albumId: albumId, serverId: song.serverId)
        }

        if let genreId = song.genreId {
            song.genre = GenreRepository.si.genre(genreId: genreId)
        }
        
        song.contentType = ContentTypeRepository.si.contentType(contentTypeId: song.contentTypeId)
        if let transcodedContentTypeId = song.transcodedContentTypeId {
            song.transcodedContentType = ContentTypeRepository.si.contentType(contentTypeId: transcodedContentTypeId)
        }
    }
}

extension Song {
    var isFullyCached: Bool {
        get {
            let query = "SELECT fullyCached FROM cachedSongsMetadata WHERE songId = ? AND serverId = ?"
            return DatabaseSingleton.si.read.boolForQuery(query, songId, serverId)
        }
        set {
            // TODO: Handle pinned column
            DatabaseSingleton.si.write.inDatabase { db in
                let query = "REPLACE INTO cachedSongsMetadata VALUES (?, ?, ?, ?, ?)"
                try? db.executeUpdate(query, self.songId, self.serverId, false, true, false)
            }
            
            // Add subItems to cache db
            loadSubItems()
            _ = folder?.cache()
            _ = artist?.cache()
            _ = album?.cache()
            _ = cache()
        }
    }
    
    var isPartiallyCached: Bool {
        get {
            let query = "SELECT partiallyCached FROM cachedSongsMetadata WHERE songId = ? AND serverId = ?"
            return DatabaseSingleton.si.read.boolForQuery(query, songId, serverId)
        }
        set {
            // TODO: Handle pinned column
            DatabaseSingleton.si.write.inDatabase { db in
                let query = "REPLACE INTO cachedSongsMetadata VALUES (?, ?, ?, ?, ?)"
                try? db.executeUpdate(query, self.songId, self.serverId, true, false, false)
            }
        }
    }
}

extension Song: PersistedItem {
    class func item(itemId: Int64, serverId: Int64, repository: ItemRepository = SongRepository.si) -> Item? {
        return (repository as? SongRepository)?.song(songId: itemId, serverId: serverId)
    }
    
    var isPersisted: Bool {
        return repository.isPersisted(song: self)
    }
    
    var hasCachedSubItems: Bool {
        return repository.hasCachedSubItems(song: self)
    }
    
    func replace() -> Bool {
        return repository.replace(song: self)
    }
    
    func cache() -> Bool {
        return repository.replace(song: self, isCachedTable: true)
    }
    
    func delete() -> Bool {
        return repository.delete(song: self)
    }
    
    func deleteCache() -> Bool {
        // TODO: Use a transaction
        var success = true
        DatabaseSingleton.si.write.inDatabase { db in
            var queries = [String]()
            
            // Remove the metadata entry
            queries.append("DELETE FROM cachedSongsMetadata WHERE songId = ? AND serverId = ?")
            
            // Remove the song table entry
            queries.append("DELETE FROM cachedSongs WHERE songId = ? AND serverId = ?")
            
            // Remove artist/album/folder entries if no other songs reference them
            queries.append("DELETE FROM cachedFolders WHERE NOT EXISTS (SELECT 1 FROM cachedSongs WHERE folderId = cachedFolders.folderId AND serverId = cachedFolders.serverId)")
            queries.append("DELETE FROM cachedArtists WHERE NOT EXISTS (SELECT 1 FROM cachedSongs WHERE artistId = cachedArtists.artistId AND serverId = cachedArtists.serverId)")
            queries.append("DELETE FROM cachedAlbums WHERE NOT EXISTS (SELECT 1 FROM cachedSongs WHERE albumId = cachedAlbums.albumId AND serverId = cachedAlbums.serverId)")
            
            for query in queries {
                do {
                    try db.executeUpdate(query, self.songId, self.serverId)
                } catch {
                    success = false
                    printError(error)
                }
            }
        }
        return success
    }
    
    func loadSubItems() {
        repository.loadSubItems(song: self)
    }
}
