//
//  ArtistRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate let artistsTable = "artists"
fileprivate let cachedArtistsTable = "cachedArtists"

struct ArtistRepository: ItemRepository {
    static var si: ArtistRepository = ArtistRepository()
    
    func artist(artistId: Int, serverId: Int, loadSubitems: Bool = false) -> Artist? {
        func runQuery(db: FMDatabase, table: String) -> Artist? {
            var artist: Artist? = nil
            let query = "SELECT * FROM \(table) WHERE artistId = ? AND serverId = ?"
            do {
                let result = try db.executeQuery(query, artistId, serverId)
                if result.next() {
                    artist = Artist(result: result)
                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
            return artist
        }
        
        var artist: Artist? = nil
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            artist = runQuery(db: db, table: artistsTable)
            if artist == nil {
                artist = runQuery(db: db, table: cachedArtistsTable)
            }
        }
        
        if loadSubitems, let artist = artist {
            artist.loadSubitems()
        }
        
        return artist
    }
    
    func allArtists(serverId: Int? = nil, isCachedTable: Bool = false) -> [Artist] {
        let ignoredArticles = DatabaseSingleton.si().ignoredArticles()
        var artists = [Artist]()
        var artistsNumbers = [Artist]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let table = isCachedTable ? cachedArtistsTable : artistsTable
            var query = "SELECT * FROM \(table)"
            do {
                let result: FMResultSet
                if let serverId = serverId {
                    query += " WHERE serverId = ?"
                    result = try db.executeQuery(query, serverId)
                } else {
                    result = try db.executeQuery(query)
                }
                
                while result.next() {
                    let artist = Artist(result: result)
                    let name = DatabaseSingleton.si().name(artist.name, ignoringArticles: ignoredArticles)
                    if let firstScalar = name.unicodeScalars.first {
                        if CharacterSet.letters.contains(firstScalar) {
                            artists.append(artist)
                        } else {
                            artistsNumbers.append(artist)
                        }
                    }
                }
                result.close()
            } catch {
                print("DB Error: \(error)")
            }
        }
        
        artists = subsonicSorted(items: artists, ignoredArticles: ignoredArticles)
        artists.append(contentsOf: artistsNumbers)
        
        for artist in artists {
            artist.loadSubitems()
        }
        
        return artists
    }
    
    func deleteAllArtists(serverId: Int?) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                if let serverId = serverId {
                    let query = "DELETE FROM \(artistsTable) WHERE serverId = ?"
                    try db.executeUpdate(query, serverId)
                } else {
                    let query = "DELETE FROM \(artistsTable)"
                    try db.executeUpdate(query)
                }
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func isPersisted(artist: Artist, isCachedTable: Bool = false) -> Bool {
        let table = isCachedTable ? cachedArtistsTable : artistsTable
        let query = "SELECT COUNT(*) FROM \(table) WHERE artistId = ? AND serverId = ?"
        return DatabaseSingleton.si().songModelReadDbPool.boolForQuery(query, artist.artistId, artist.serverId)
    }
    
    func hasCachedSubItems(artist: Artist) -> Bool {
        let query = "SELECT COUNT(*) FROM cachedSongs WHERE artistId = ? AND serverId = ?"
        return DatabaseSingleton.si().songModelReadDbPool.boolForQuery(query, artist.artistId, artist.serverId)
    }
    
    func replace(artist: Artist, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = isCachedTable ? cachedArtistsTable : artistsTable
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?)"
                try db.executeUpdate(query, artist.artistId, artist.serverId, artist.name, n2N(artist.coverArtId), n2N(artist.albumCount))
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func delete(artist: Artist, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = isCachedTable ? cachedArtistsTable : artistsTable
                let query = "DELETE FROM \(table) WHERE artistId = ? AND serverId = ?"
                try db.executeUpdate(query, artist.artistId, artist.serverId)
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func loadSubItems(artist: Artist) {
        artist.albums = AlbumRepository.si.albums(artistId: artist.artistId, serverId: artist.serverId, isCachedTable: false)
    }
}

extension Artist {
    convenience init(result: FMResultSet, repository: ArtistRepository = ArtistRepository.si) {
        let artistId    = result.long(forColumnIndex: 0)
        let serverId    = result.long(forColumnIndex: 1)
        let name        = result.string(forColumnIndex: 2) ?? ""
        let coverArtId  = result.string(forColumnIndex: 3)
        let albumCount  = result.object(forColumnIndex: 4) as? Int
        self.init(artistId: artistId, serverId: serverId, name: name, coverArtId: coverArtId, albumCount: albumCount, repository: repository)
    }
}

extension Artist: PersistedItem {
    var isPersisted: Bool {
        return repository.isPersisted(artist: self)
    }
    
    var hasCachedSubItems: Bool {
        return repository.hasCachedSubItems(artist: self)
    }
    
    func replace() -> Bool {
        return repository.replace(artist: self)
    }
    
    func cache() -> Bool {
        return repository.replace(artist: self, isCachedTable: true)
    }
    
    func delete() -> Bool {
        return repository.delete(artist: self)
    }
    
    func loadSubitems() {
        repository.loadSubItems(artist: self)
    }
}
