//
//  SearchLoader.swift
//  iSub Beta
//
//  Created by Andres Felipe Rodriguez Bolivar on 12/1/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

public enum SearchType {
    case folderBased
    case artistBased
}

class SearchLoader: ApiLoader, ItemLoader {
    
    var associatedItem: Item?
    var items: [Item] = []
    
    private var queryString: String?
    private var searchType: SearchType
    
    override init() {
        searchType = .artistBased
        super.init()
    }
    
    init(with type: SearchType, serverId: Int64) {
        searchType = type
        super.init(serverId: serverId)
    }
    
    func performSearch(with text: String) -> URLRequest? {
        queryString = text
        return createRequest()
    }
    
    override func createRequest() -> URLRequest? {
        guard let text = queryString else {
            NSLog("Nothing to search")
            return nil
        }
        let action: SubsonicURLAction = searchType == .folderBased ? .search2 : .search3
        return URLRequest(subsonicAction: action,
                          serverId: serverId,
                          parameters: ["query": text])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        var artists: [Artist] = []
        var albums: [Album] = []
        var songs: [Song] = []
        let query = searchType == .folderBased ? "searchResult2" : "searchResult3"
        let server = serverId
        // artists
        root.iterate(query + ".artist") {
            if let artist = Artist(rxmlElement: $0, serverId: server) {
                artists.append(artist)
            }
        }
        
        // albums
        root.iterate(query + ".album") {
            if let album = Album(rxmlElement: $0, serverId: server) {
                albums.append(album)
            }
        }
        
        // songs
        root.iterate(query + ".song") {
            if let song = Song(rxmlElement: $0, serverId: server) {
                songs.append(song)
            }
        }
        
        return artists.count > 0 || albums.count > 0 || songs.count > 0
    }
    
    func persistModels() {}
    
    func loadModelsFromDatabase() -> Bool {
        return true
    }
    
}
