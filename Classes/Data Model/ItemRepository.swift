//
//  ItemRepository.swift
//  iSub
//
//  Created by Benjamin Baron on 1/14/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

protocol ItemRepository {}

protocol NamedItem {
    var name: String { get }
}
extension Artist: NamedItem {}
extension Album: NamedItem {}

func subsonicSorted<T: NamedItem>(items: [T], ignoredArticles: [String]) -> [T] {
    return items.sorted {
        var name1 = DatabaseSingleton.si().name($0.name.lowercased(), ignoringArticles: ignoredArticles)
        name1 = name1.replacingOccurrences(of: " ", with: "")
        name1 = name1.replacingOccurrences(of: "-", with: "")
        
        var name2 = DatabaseSingleton.si().name($1.name.lowercased(), ignoringArticles: ignoredArticles)
        name2 = name2.replacingOccurrences(of: " ", with: "")
        name2 = name2.replacingOccurrences(of: "-", with: "")
        
        return name1 < name2
    }
}
