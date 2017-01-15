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
    let itemId = "songId"
    
    func song(songId: Int, serverId: Int, loadSubItems: Bool = false) -> Song? {
        return gr.item(repository: self, itemId: songId, serverId: serverId, loadSubItems: loadSubItems)
    }
    
    func allAlbums(serverId: Int? = nil, isCachedTable: Bool = false) -> [Album] {
        return gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func deleteAllAlbums(serverId: Int?) -> Bool {
        return gr.deleteAllItems(repository: self, serverId: serverId)
    }
    
    func isPersisted(song: Song, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, item: song, isCachedTable: isCachedTable)
    }
    
    func isPersisted(songId: Int, serverId: Int, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, itemId: songId, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func hasCachedSubItems(song: Song) -> Bool {
        return gr.hasCachedSubItems(repository: self, item: song)
    }
    
    func delete(song: Song, isCachedTable: Bool = false) -> Bool {
        return gr.delete(repository: self, item: song, isCachedTable: isCachedTable)
    }
    
    func lastPlayed(songId: Int, serverId: Int, isCachedTable: Bool = false) -> Date? {
        var lastPlayed: Date? = nil
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
            let query = "SELECT lastPlayed FROM \(table) WHERE songId = ? AND serverId = ?"
            lastPlayed = db.dateForQuery(query, songId, serverId)
        }
        return lastPlayed
    }
    
    func songs(albumId: Int, serverId: Int, isCachedTable: Bool) -> [Song] {
        var songs = [Song]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
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
                print("DB Error: \(error)")
            }
        }
        return songs
    }
    
    func songs(folderId: Int, serverId: Int, isCachedTable: Bool) -> [Song] {
        var songs = [Song]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
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
                print("DB Error: \(error)")
            }
        }
        return songs
    }
    
    func replace(song: Song, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = tableName(repository: self, isCachedTable: isCachedTable)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, song.songId, song.serverId, song.contentTypeId, n2N(song.transcodedContentTypeId), n2N(song.mediaFolderId), n2N(song.folderId), n2N(song.artistId), n2N(song.albumId), n2N(song.genreId), n2N(song.coverArtId), song.title, n2N(song.duration), n2N(song.bitrate), n2N(song.trackNumber), n2N(song.discNumber), n2N(song.year), song.size, song.path, n2N(song.lastPlayed), n2N(song.artistName), n2N(song.albumName))
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func loadSubItems(song: Song) {
        if let folderId = song.folderId {
            song.folder = FolderRepository.si.folder(folderId: folderId, serverId: song.serverId, loadSubItems: false)
        }
        
        if let artistId = song.artistId {
            song.artist = ArtistRepository.si.artist(artistId: artistId, serverId: song.serverId, loadSubItems: false)
        }
        
        if let albumId = song.albumId {
            song.album = AlbumRepository.si.album(albumId: albumId, serverId: song.serverId, loadSubItems: false)
        }

        if let genreId = song.genreId {
            song.genre = GenreRepository.si.genre(genreId: genreId)
        }
        
        song.contentType = ISMSContentType(contentTypeId: song.contentTypeId)!
        
        if let transcodedContentTypeId = song.transcodedContentTypeId {
            song.transcodedContentType = ISMSContentType(contentTypeId: transcodedContentTypeId)
        }
    }
}

extension Song: PersistedItem {
    class func item(itemId: Int, serverId: Int, repository: ItemRepository = SongRepository.si) -> Item? {
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
    
    func loadSubItems() {
        repository.loadSubItems(song: self)
    }
}
