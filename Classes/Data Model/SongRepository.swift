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
    
    func allSongs(serverId: Int64? = nil, isCachedTable: Bool = false, loadSubItems: Bool = false) -> [Song] {
        return gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable, loadSubItems: loadSubItems)
    }
    
    @discardableResult func deleteAllSongs(serverId: Int64?) -> Bool {
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
        Database.si.read.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            let query = "SELECT lastPlayed FROM \(table) WHERE songId = ? AND serverId = ?"
            lastPlayed = db.dateForQuery(query, songId, serverId)
        }
        return lastPlayed
    }
    
    @discardableResult func deleteRootSongs(mediaFolderId: Int64?, serverId: Int64, isCachedTable: Bool = false) -> Bool {
        var success = true
        Database.si.read.inDatabase { db in
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
        Database.si.read.inDatabase { db in
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
        Database.si.read.inDatabase { db in
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
        Database.si.read.inDatabase { db in
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
        Database.si.write.inDatabase { db in
            do {
                let table = tableName(repository: self, isCachedTable: isCachedTable)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, song.songId, song.serverId, song.contentTypeId, n2N(song.transcodedContentTypeId), n2N(song.mediaFolderId), n2N(song.folderId), n2N(song.artistId), n2N(song.albumId), n2N(song.genreId), n2N(song.coverArtId), song.title, n2N(song.duration), n2N(song.bitRate), n2N(song.trackNumber), n2N(song.discNumber), n2N(song.year), song.size, song.path, n2N(song.lastPlayed), n2N(song.artistName), n2N(song.albumName))
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
            return Database.si.read.boolForQuery(query, songId, serverId)
        }
        set {
            // TODO: Handle pinned column
            Database.si.write.inDatabase { db in
                let query = "REPLACE INTO cachedSongsMetadata VALUES (?, ?, ?, ?, ?)"
                try? db.executeUpdate(query, self.songId, self.serverId, false, true, false)
            }
            
            // Add subItems to cache db
            loadSubItems()
            folder?.cache()
            artist?.cache()
            album?.cache()
            cache()
        }
    }
    
    var isPartiallyCached: Bool {
        get {
            let query = "SELECT partiallyCached FROM cachedSongsMetadata WHERE songId = ? AND serverId = ?"
            return Database.si.read.boolForQuery(query, songId, serverId)
        }
        set {
            // TODO: Handle pinned column
            Database.si.write.inDatabase { db in
                let query = "REPLACE INTO cachedSongsMetadata VALUES (?, ?, ?, ?, ?)"
                try? db.executeUpdate(query, self.songId, self.serverId, true, false, false)
            }
        }
    }
}

extension Song: PersistedItem {
    convenience init(result: FMResultSet, repository: ItemRepository = SongRepository.si) {
        let songId                  = result.longLongInt(forColumnIndex: 0)
        let serverId                = result.longLongInt(forColumnIndex: 1)
        let contentTypeId           = result.longLongInt(forColumnIndex: 2)
        let transcodedContentTypeId = result.object(forColumnIndex: 3) as? Int64
        let mediaFolderId           = result.object(forColumnIndex: 4) as? Int64
        let folderId                = result.object(forColumnIndex: 5) as? Int64
        let artistId                = result.object(forColumnIndex: 6) as? Int64
        let albumId                 = result.object(forColumnIndex: 7) as? Int64
        let genreId                 = result.object(forColumnIndex: 8) as? Int64
        let coverArtId              = result.string(forColumnIndex: 9)
        let title                   = result.string(forColumnIndex: 10) ?? ""
        let duration                = result.object(forColumnIndex: 11) as? Int
        let bitRate                 = result.object(forColumnIndex: 12) as? Int
        let trackNumber             = result.object(forColumnIndex: 13) as? Int
        let discNumber              = result.object(forColumnIndex: 14) as? Int
        let year                    = result.object(forColumnIndex: 15) as? Int
        let size                    = result.longLongInt(forColumnIndex: 16)
        let path                    = result.string(forColumnIndex: 17) ?? ""
        let lastPlayed              = result.date(forColumnIndex: 18)
        let artistName              = result.string(forColumnIndex: 19)
        let albumName               = result.string(forColumnIndex: 20)
        let repository              = repository as! SongRepository
        
        // Preload genre object
        var genre: Genre?
        if let genreId = genreId, let maybeGenre = GenreRepository.si.genre(genreId: genreId) {
            genre = maybeGenre
        }

        // Preload content type objects
        let contentType = ContentTypeRepository.si.contentType(contentTypeId: contentTypeId)
        var transcodedContentType: ContentType? = nil
        if let transcodedContentTypeId = transcodedContentTypeId {
            transcodedContentType = ContentTypeRepository.si.contentType(contentTypeId: transcodedContentTypeId)
        }
        
        self.init(songId: songId, serverId: serverId, contentTypeId: contentTypeId, transcodedContentTypeId: transcodedContentTypeId, mediaFolderId: mediaFolderId, folderId: folderId, artistId: artistId, artistName: artistName, albumId: albumId, albumName: albumName, genreId: genreId, coverArtId: coverArtId, title: title, duration: duration, bitRate: bitRate, trackNumber: trackNumber, discNumber: discNumber, year: year, size: size, path: path, lastPlayed: lastPlayed, genre: genre, contentType: contentType, transcodedContentType: transcodedContentType, repository: repository)
    }
    
    class func item(itemId: Int64, serverId: Int64, repository: ItemRepository = SongRepository.si) -> Item? {
        return (repository as? SongRepository)?.song(songId: itemId, serverId: serverId)
    }
    
    var isPersisted: Bool {
        return repository.isPersisted(song: self)
    }
    
    var hasCachedSubItems: Bool {
        return repository.hasCachedSubItems(song: self)
    }
    
    @discardableResult func replace() -> Bool {
        return repository.replace(song: self)
    }
    
    @discardableResult func cache() -> Bool {
        return repository.replace(song: self, isCachedTable: true)
    }
    
    @discardableResult func delete() -> Bool {
        return repository.delete(song: self)
    }
    
    @discardableResult func deleteCache() -> Bool {
        var success = true
        Database.si.write.inDatabase { db in
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
