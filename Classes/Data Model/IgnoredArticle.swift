//
//  IgnoredArticle.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 9/17/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension IgnoredArticle: Item, Equatable {
    var itemId: Int64 { return articleId }
    var itemName: String { return name }
    var coverArtId: String? { return nil }
}

final class IgnoredArticle {
    let repository: IgnoredArticleRepository
    
    let articleId: Int64
    let serverId: Int64
    let name: String
    
    // This must be marked required or we get a crash due to a Swift bug
    required init(result: FMResultSet, repository: ItemRepository = IgnoredArticleRepository.si) {
        self.articleId = result.longLongInt(forColumnIndex: 0)
        self.serverId = result.longLongInt(forColumnIndex: 1)
        self.name = result.string(forColumnIndex: 1) ?? ""
        self.repository = repository as! IgnoredArticleRepository
    }
    
    static func ==(lhs: IgnoredArticle, rhs: IgnoredArticle) -> Bool {
        return lhs.name == rhs.name
    }
}
