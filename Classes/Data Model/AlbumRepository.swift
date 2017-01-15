//
//  AlbumRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate let albumsTable = "albums"
fileprivate let cachedAlbumsTable = "cachedAlbums"

struct AlbumRepository: ItemRepository {
    static var si: AlbumRepository = AlbumRepository()
    
    func album(albumId: Int, serverId: Int, loadSubitems: Bool = false) -> Album? {
        func runQuery(db: FMDatabase, table: String) -> Album? {
            var album: Album? = nil
            let query = "SELECT * FROM \(table) WHERE albumId = ? AND serverId = ?"
            do {
                let result = try db.executeQuery(query, albumId, serverId)
                if result.next() {
                    album = Album(result: result)
                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
            return album
        }
        
        var album: Album? = nil
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            album = runQuery(db: db, table: albumsTable)
            if album == nil {
                album = runQuery(db: db, table: cachedAlbumsTable)
            }
        }
        
        if loadSubitems, let album = album {
            album.loadSubitems()
        }
        
        return album
    }
    
    func albums(artistId: Int, serverId: Int, isCachedTable: Bool) -> [Album] {
        var albums = [Album]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let table = isCachedTable ? cachedAlbumsTable : albumsTable
            let query = "SELECT * FROM \(table) WHERE artistId = ? AND serverId = ?"
            do {
                let result = try db.executeQuery(query, artistId, serverId)
                while result.next() {
                    let album = Album(result: result)
                    albums.append(album)
                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
        }
        return albums
    }
    
    fileprivate func subsonicSorted(albums: [Album], ignoredArticles: [String]) -> [Album] {
        return albums.sorted {
            var name1 = DatabaseSingleton.si().name($0.name.lowercased(), ignoringArticles: ignoredArticles)
            name1 = name1.replacingOccurrences(of: " ", with: "")
            name1 = name1.replacingOccurrences(of: "-", with: "")
            
            var name2 = DatabaseSingleton.si().name($1.name.lowercased(), ignoringArticles: ignoredArticles)
            name2 = name2.replacingOccurrences(of: " ", with: "")
            name2 = name2.replacingOccurrences(of: "-", with: "")
            
            return name1 < name2
        }
    }
    
    func allAlbums(serverId: Int?) -> [Album] {
        let ignoredArticles = DatabaseSingleton.si().ignoredArticles()
        var albums = [Album]()
        var albumsNumbers = [Album]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            var query = "SELECT * FROM \(albumsTable)"
            do {
                let result: FMResultSet
                if let serverId = serverId {
                    query += " WHERE serverId = ?"
                    result = try db.executeQuery(query, serverId)
                } else {
                    result = try db.executeQuery(query)
                }
                
                while result.next() {
                    let album = Album(result: result)
                    let name = DatabaseSingleton.si().name(album.name, ignoringArticles: ignoredArticles)
                    if let firstScalar = name.unicodeScalars.first {
                        if CharacterSet.letters.contains(firstScalar) {
                            albums.append(album)
                        } else {
                            albumsNumbers.append(album)
                        }
                    }
                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
        }
        
        albums = subsonicSorted(albums: albums, ignoredArticles: ignoredArticles)
        albums.append(contentsOf: albumsNumbers)
        
        for album in albums {
            album.loadSubitems()
        }
        
        return albums
    }
    
    func allCachedAlbums() -> [Album] {
        let ignoredArticles = DatabaseSingleton.si().ignoredArticles()
        var albums = [Album]()
        var albumsNumbers = [Album]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let query = "SELECT * FROM \(cachedAlbumsTable)"
            do {
                let result = try db.executeQuery(query)
                while result.next() {
                    let album = Album(result: result)
                    let name = DatabaseSingleton.si().name(album.name, ignoringArticles: ignoredArticles)
                    if let firstScalar = name.unicodeScalars.first {
                        if CharacterSet.letters.contains(firstScalar) {
                            albums.append(album)
                        } else {
                            albumsNumbers.append(album)
                        }
                    }

                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
        }
        
        albums = subsonicSorted(albums: albums, ignoredArticles: ignoredArticles)
        albums.append(contentsOf: albumsNumbers)
        
        for album in albums {
            album.loadSubitems()
        }
        
        return albums
    }
    
    func deleteAllAlbums(serverId: Int?) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                if let serverId = serverId {
                    let query = "DELETE FROM \(albumsTable) WHERE serverId = ?"
                    try db.executeUpdate(query, serverId)
                } else {
                    let query = "DELETE FROM \(albumsTable)"
                    try db.executeUpdate(query)
                }
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func isPersisted(album: Album, isCachedTable: Bool = false) -> Bool {
        let table = isCachedTable ? cachedAlbumsTable : albumsTable
        let query = "SELECT COUNT(*) FROM \(table) WHERE albumId = ? AND serverId = ?"
        return DatabaseSingleton.si().songModelReadDbPool.boolForQuery(query, album.albumId, album.serverId)
    }
    
    func hasCachedSubItems(album: Album) -> Bool {
        let query = "SELECT COUNT(*) FROM cachedSongs WHERE albumId = ? AND serverId = ?"
        return DatabaseSingleton.si().songModelReadDbPool.boolForQuery(query, album.albumId, album.serverId)
    }
    
    func replace(album: Album, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = isCachedTable ? cachedAlbumsTable : albumsTable
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, album.albumId, album.serverId, n2N(album.artistId), n2N(album.genreId), n2N(album.coverArtId), album.name, n2N(album.songCount), n2N(album.duration), n2N(album.year), n2N(album.created))
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func delete(album: Album, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = isCachedTable ? cachedAlbumsTable : albumsTable
                let query = "DELETE FROM \(table) WHERE albumId = ? AND serverId = ?"
                try db.executeUpdate(query, album.albumId, album.serverId)
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func loadSubItems(album: Album) {
        if let artistId = album.artistId {
            album.artist = ISMSArtist(artistId: artistId, serverId: album.serverId, loadSubmodels: false)
        }
 
        if let genreId = album.genreId {
            album.genre = ISMSGenre(genreId: genreId)
        }
        
        album.songs = ISMSSong.songs(inAlbum: album.albumId, serverId: album.serverId, cachedTable: false)
    }
}

extension Album {
    convenience init(result: FMResultSet, repository: AlbumRepository = AlbumRepository.si) {
        let albumId     = result.long(forColumnIndex: 0)
        let serverId    = result.long(forColumnIndex: 1)
        let artistId    = result.object(forColumnIndex: 2) as? Int
        let genreId     = result.object(forColumnIndex: 3) as? Int
        let coverArtId  = result.string(forColumnIndex: 4)
        let name        = result.string(forColumnIndex: 5) ?? ""
        let songCount   = result.object(forColumnIndex: 6) as? Int
        let duration    = result.object(forColumnIndex: 7) as? Int
        let year        = result.object(forColumnIndex: 8) as? Int
        let created     = result.date(forColumnIndex: 9)
        self.init(albumId: albumId, serverId: serverId, artistId: artistId, genreId: genreId, coverArtId: coverArtId, name: name, songCount: songCount, duration: duration, year: year, created: created, repository: repository)
    }
}

extension Album: PersistedItem {
    var isPersisted: Bool {
        return repository.isPersisted(album: self)
    }
    
    var hasCachedSubItems: Bool {
        return repository.hasCachedSubItems(album: self)
    }
    
    func replace() -> Bool {
        return repository.replace(album: self)
    }
    
    func cache() -> Bool {
        return repository.replace(album: self, isCachedTable: true)
    }
    
    func delete() -> Bool {
        return repository.delete(album: self)
    }
    
    func loadSubitems() {
        repository.loadSubItems(album: self)
    }
}
