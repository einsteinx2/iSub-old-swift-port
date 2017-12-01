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
    var items: [Item]
    private var size: Int?
    
    override init(with size: Int, and serverId: Int64) {
        self.size = size
        super.init(serverId: serverId)
    }
    
    override func createRequest() -> URLRequest? {
        return URLRequest(subsonicAction: .getRandomSongs,
                          serverId: serverId,
                          parameters: ["size" : size ?? 10])
    }
    
    override func processResponse(root: RXMLElement) -> Bool {
        
        var songs: [Song] = []
        let server = serverId
        root.iterate("randomSongs.song") {
            if let song = Song(rxmlElement: $0, serverId: server) {
                songs.append(contentsOf: song)
            }
        }
        
        items = songs
        
        return items.count > 0
        
    }
    
    func persistModels() {}
    
    func loadModelsFromDatabase() -> Bool {
        return true
    }
    
}
