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

func ==<T: Item>(lhs: T, rhs: T) -> Bool {
    return lhs.itemId == rhs.itemId
}

//func !=<T: Item>(lhs: T, rhs: T) -> Bool {
//    return lhs.identifier() != rhs.identifier()
//}

func ==<T: Item, U:Item>(lhs: T, rhs: U) -> Bool {
    return lhs.itemId == rhs.itemId
}

//func !=<T:Item, U:Item>(lhs: T, rhs: U) -> Bool {
//    return lhs.identifier() != rhs.identifier()
//}
