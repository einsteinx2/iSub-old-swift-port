//
//  CachedDatabaseLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedDatabaseLoader: ItemLoader {
    var completionHandler: ApiLoaderCompletionHandler?
    
    let serverId: Int64
    
    var associatedItem: Item? {
        return nil
    }
    
    var items: [Item] {
        return [Item]()
    }
    
    var state: ApiLoaderState = .new
    
    @discardableResult func loadModelsFromDatabase() -> Bool {
        fatalError("Override in subclass")
    }
    
    // Not implemented
    func persistModels() {}
    func start() {}
    func cancel() {}
    
    init(serverId: Int64) {
        self.serverId = serverId
    }
}
