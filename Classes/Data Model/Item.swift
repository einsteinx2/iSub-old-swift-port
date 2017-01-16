//
//  Item.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

protocol Item {
    var itemId: Int64 { get }
    var itemName: String { get }
    var serverId: Int64 { get }
}

protocol PersistedItem: Item {
    var isPersisted: Bool { get }
    var hasCachedSubItems: Bool { get }
    
    func replace() -> Bool
    func cache() -> Bool
    func delete() -> Bool
    func deleteCache() -> Bool
    func loadSubItems()
    
    static func item(itemId: Int64, serverId: Int64, repository: ItemRepository) -> Item?
    init(result: FMResultSet, repository: ItemRepository)
}
