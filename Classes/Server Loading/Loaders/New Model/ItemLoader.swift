//
//  ItemLoader.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

protocol ItemLoader {
    var completionHandler: ApiLoaderCompletionHandler? { get set }
    
    var serverId: Int64 { get }
    
    var associatedItem: Item? { get }
    
    var items: [Item] { get }
    
    var state: ApiLoaderState { get }
    
    func start()
    func cancel()
}

protocol PersistedItemLoader: ItemLoader {
    func persistModels()
    func loadModelsFromDatabase() -> Bool
}

protocol RootItemLoader: PersistedItemLoader {
    var mediaFolderId: Int64? { get set }
}
