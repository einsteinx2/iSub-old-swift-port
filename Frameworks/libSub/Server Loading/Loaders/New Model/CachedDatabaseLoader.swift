//
//  CachedDatabaseLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class CachedDatabaseLoader: ItemLoader {
    weak var delegate: ApiLoaderDelegate?
    var completionHandler: ApiLoaderCompletionHandler?
    
    var associatedObject: Any? {
        return nil
    }
    
    var items: [ISMSItem] {
        return [ISMSItem]()
    }
    
    var state: ApiLoaderState = .new
    
    func loadModelsFromDatabase() -> Bool {
        fatalError("Override in subclass")
    }
    
    // Not implemented
    func persistModels() {}
    func start() {}
    func cancel() {}
}
