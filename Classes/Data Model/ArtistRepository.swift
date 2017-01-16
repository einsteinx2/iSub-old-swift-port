//
//  ArtistRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct ArtistRepository: ItemRepository {
    static let si = ArtistRepository()
    fileprivate let gr = GenericItemRepository.si

    let table = "artists"
    let cachedTable = "cachedArtists"
    let itemIdField = "artistId"
    
    func artist(artistId: Int64, serverId: Int64, loadSubItems: Bool = false) -> Artist? {
        return gr.item(repository: self, itemId: artistId, serverId: serverId, loadSubItems: loadSubItems)
    }
    
    func allArtists(serverId: Int64? = nil, isCachedTable: Bool = false) -> [Artist] {
        let artists: [Artist] = gr.allItems(repository: self, serverId: serverId, isCachedTable: isCachedTable)
        return subsonicSorted(items: artists, ignoredArticles: DatabaseSingleton.si.ignoredArticles)
    }
    
    func deleteAllArtists(serverId: Int64?) -> Bool {
        return gr.deleteAllItems(repository: self, serverId: serverId)
    }
    
    func isPersisted(artist: Artist, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, item: artist, isCachedTable: isCachedTable)
    }
    
    func isPersisted(artistId: Int64, serverId: Int64, isCachedTable: Bool = false) -> Bool {
        return gr.isPersisted(repository: self, itemId: artistId, serverId: serverId, isCachedTable: isCachedTable)
    }
    
    func hasCachedSubItems(artist: Artist) -> Bool {
        return gr.hasCachedSubItems(repository: self, item: artist)
    }
    
    func delete(artist: Artist, isCachedTable: Bool = false) -> Bool {
        return gr.delete(repository: self, item: artist, isCachedTable: isCachedTable)
    }
    
    func replace(artist: Artist, isCachedTable: Bool = false) -> Bool {
        var success = true
        DatabaseSingleton.si.write.inDatabase { db in
            do {
                let table = tableName(repository: self, isCachedTable: isCachedTable)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?, ?, ?)"
                try db.executeUpdate(query, artist.artistId, artist.serverId, artist.name, n2N(artist.coverArtId), n2N(artist.albumCount))
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func loadSubItems(artist: Artist) {
        artist.albums = AlbumRepository.si.albums(artistId: artist.artistId, serverId: artist.serverId)
    }
}

extension Artist: PersistedItem {
    class func item(itemId: Int64, serverId: Int64, repository: ItemRepository = ArtistRepository.si) -> Item? {
        return (repository as? ArtistRepository)?.artist(artistId: itemId, serverId: serverId)
    }
    
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
    
    func deleteCache() -> Bool {
        return repository.delete(artist: self, isCachedTable: true)
    }
    
    func loadSubItems() {
        repository.loadSubItems(artist: self)
    }
}
