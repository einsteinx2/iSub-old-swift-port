//
//  SimilarSongsLoader.swift
//  iSub Beta
//
//  Created by Felipe Rolvar on 3/12/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class SimilarSongsLoader: ApiLoader, ItemLoader {
    
    var associatedItem: Item?
    var songs = [Song]()
    var artistId: Int64
    var sorted: Bool
    var count: Int = 50
    var items: [Item] {
        return songs as [Item]
    }
    
    init(serverId: Int64, artistId: Int64, sortedId3: Bool = false) {
        self.artistId = artistId
        self.sorted = sortedId3
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: sorted ? .getSimilarSongs2 : .getSimilarSongs,
                          serverId: serverId,
                          parameters: ["id" : artistId,
                                       "count" : count])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        root.iterate("similarSongs" + (sorted ? "2" : "")) { [weak self] in
            guard let `self` = self else { return }
            if let song = Song(rxmlElement: $0, serverId: self.serverId) {
                self.songs.append(song)
            }
        }
        
        return items.count > 0
    }
    
}
