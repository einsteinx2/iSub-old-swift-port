//
//  RamdomSongsLoader.swift
//  iSub Beta
//
//  Created by Andres Felipe Rodriguez Bolivar on 12/1/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class RandomSongsLoader: ApiLoader, ItemLoader {
    
    var associatedItem: Item?
    var songs = [Song]()
    
    var items: [Item] {
        return songs as [Item]
    }
    private var size: Int
    
    override init(serverId: Int64, and size: Int = 10) {
        self.size = size
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .getRandomSongs,
                          serverId: serverId,
                          parameters: ["size" : size])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {

        let server = serverId
        root.iterate("randomSongs.song") {
            if let song = Song(rxmlElement: $0, serverId: server) {
                songs.append(contentsOf: song)
            }
        }
        
        items = songs
        
        return items.count > 0
        
    }
}
