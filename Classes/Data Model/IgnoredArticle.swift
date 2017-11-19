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
    
    static func ==(lhs: IgnoredArticle, rhs: IgnoredArticle) -> Bool {
        return lhs.name == rhs.name
    }
}

final class IgnoredArticle {
    let repository: IgnoredArticleRepository
    
    let articleId: Int64
    let serverId: Int64
    let name: String
    
    init(articleId: Int64, serverId: Int64, name: String, repository: IgnoredArticleRepository = IgnoredArticleRepository.si) {
        self.articleId = articleId
        self.serverId = serverId
        self.name = name
        
        self.repository = repository
    }
}
