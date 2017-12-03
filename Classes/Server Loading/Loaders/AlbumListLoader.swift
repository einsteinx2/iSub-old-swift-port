//
//  AlbumListLoader.swift
//  iSub Beta
//
//  Created by Felipe Rolvar on 3/12/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class AlbumListLoader: ApiLoader, ItemLoader {
    
    enum albumType: String {
        case random
        case newest
        case highest
        case frequent
        case recent
        case alphabeticalByName
        case alphabeticalByArtist
        case starred
        case byYear
        case byGenre
    }
    
    var sortedId: Bool
    var albumbs = [Album]()
    var type: albumType?
    var size: Int = 10
    var offset: Int = 0
    var fromYear: Int?
    var toYear: Int?
    var genre: Genre?
    var musicFolderId: String?
    
    var associatedItem: Item?
    var items: [Item] {
        return albumbs as [Item]
    }
    
    init(serverId: Int64, sortedId3: Bool) {
        self.sortedId = sortedId3
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        
        guard let parameters = getRequestParameters() else {
            print("Invalid request parameters")
            return nil
        }
        
        return URLRequest(subsonicAction: sortedId ? .getAlbumList2 : .getAlbumList,
                          serverId: serverId,
                          parameters: parameters)
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        
        root.iterate("albumList") { [weak self] in
            guard let `self` = self else { return }
            if let album = Album(rxmlElement: $0, serverId: self.serverId) {
                self.albumbs.append(album)
            }
        }
        
        return items.count > 0
    }
}

private extension AlbumListLoader {
    
    func getRequestParameters() -> [String: Any]? {
        guard let type = type else {
            print("AlbumListLoader: Type property is required")
            return nil
        }
        guard let fromYear = fromYear else {
            print("AlbumListLoader: fromYear property is required")
            return nil
        }
        guard let toYear = toYear else {
            print("AlbumListLoader: toYear property is required")
            return nil
        }
        
        var params = [String: Any]()
        params["type"] = type
        params["fromYear"] = fromYear
        params["toYear"] = toYear
        
        if size > 10 {
            params["size"] = size
        }
        
        if offset > 0 {
            params["offset"] = offset
        }
        
        if let musicFolderId = musicFolderId {
            params["musicFolerid"] = musicFolderId
        }
        
        return params
    }
    
}
