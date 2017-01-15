//
//  AlbumRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct AlbumRepository: ItemRepository {
    static let si = AlbumRepository()
    fileprivate let gr = GenericItemRepository.si

    let table = "albums"
    let cachedTable = "cachedAlbums"
    let itemId = "albumId"
    
    func album(albumId: Int, serverId: Int, loadSubItems: Bool = false) -> Album? {
        return gr.item(repository: self, itemId: albumId, serverId: serverId, loadSubItems: loadSubItems)
    }
    
    func allAlbums(serverId: Int? = nil, isCachedTable: Bool = false) -> [Album] {
        return gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func deleteAllAlbums(serverId: Int?) -> Bool {
        return gr.deleteAllItems(repository: self, serverId: serverId)
    }
    
    func isPersisted(album: Album, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, item: album, isCachedTable: isCachedTable)
    }
    
    func hasCachedSubItems(album: Album) -> Bool {
        return gr.hasCachedSubItems(repository: self, item: album)
    }
    
    func delete(album: Album, isCachedTable: Bool = false) -> Bool {
        return gr.delete(repository: self, item: album, isCachedTable: isCachedTable)
    }
    
    func albums(artistId: Int, serverId: Int, isCachedTable: Bool) -> [Album] {
        var albums = [Album]()
        DatabaseSingleton.si().songModelReadDbPool.inDatabase { db in
            let table = tableName(repository: self, isCachedTable: isCachedTable)
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
    
    func replace(album: Album, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si().songModelWritesDbQueue.inDatabase { db in
            do {
                let table = tableName(repository: self, isCachedTable: isCachedTable)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)"
                try db.executeUpdate(query, album.albumId, album.serverId, n2N(album.artistId), n2N(album.genreId), n2N(album.coverArtId), album.name, n2N(album.songCount), n2N(album.duration), n2N(album.year), n2N(album.created))
            } catch {
                success = false
                print("DB Error: \(error)")
            }
        }
        return success
    }
    
    func loadSubItems(album: Album) {
        if let artistId = album.artistId {
            album.artist = ArtistRepository.si.artist(artistId: artistId, serverId: album.serverId, loadSubItems: false)
        }
 
        if let genreId = album.genreId {
            album.genre = GenreRepository.si.genre(genreId: genreId)
        }
        
        album.songs = SongRepository.si.songs(albumId: album.albumId, serverId: album.serverId, isCachedTable: false)
    }
}

extension Album: PersistedItem {
    class func item(itemId: Int, serverId: Int, repository: ItemRepository = AlbumRepository.si) -> Item? {
        return (repository as? AlbumRepository)?.album(albumId: itemId, serverId: serverId)
    }
    
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
    
    func loadSubItems() {
        repository.loadSubItems(album: self)
    }
}
