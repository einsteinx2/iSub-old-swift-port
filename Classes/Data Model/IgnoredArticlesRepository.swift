//
//  IgnoredArticlesRepository.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 9/17/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct IgnoredArticleRepository: ItemRepository {
    static let si = IgnoredArticleRepository()
    fileprivate let gr = GenericItemRepository.si
    
    let table = "ignoredArticles"
    let cachedTable = "ignoredArticles"
    let itemIdField = "articleId"
    
    func article(articleId: Int64, serverId: Int64) -> IgnoredArticle? {
        return gr.item(repository: self, itemId: articleId, serverId: serverId)
    }
    
    func allArticles(serverId: Int64? = nil) -> [IgnoredArticle] {
        return gr.allItems(repository: self, serverId: serverId)
    }
    
    @discardableResult func deleteAllArticles(serverId: Int64?) -> Bool {
        return gr.deleteAllItems(repository: self, serverId: serverId)
    }
    
    func isPersisted(article: IgnoredArticle) -> Bool {
        return gr.isPersisted(repository: self, item: article)
    }
    
    func isPersisted(articleId: Int64, serverId: Int64) -> Bool {
        return gr.isPersisted(repository: self, itemId: articleId, serverId: serverId)
    }
    
    func delete(article: IgnoredArticle) -> Bool {
        return gr.delete(repository: self, item: article)
    }
    
    func articles(serverId: Int64) -> [IgnoredArticle] {
        var articles = [IgnoredArticle]()
        Database.si.read.inDatabase { db in
            let table = tableName(repository: self)
            let query = "SELECT * FROM \(table) WHERE serverId = ?"
            do {
                let result = try db.executeQuery(query, serverId)
                while result.next() {
                    let article = IgnoredArticle(result: result)
                    articles.append(article)
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        return articles
    }
    
    func insert(serverId: Int64, name: String) -> Bool {
        var success = true
        Database.si.write.inDatabase { db in
            do {
                let table = tableName(repository: self)
                let query = "INSERT INTO \(table) VALUES (?, ?, ?)"
                try db.executeUpdate(query, NSNull(), serverId, name)
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
    
    func replace(article: IgnoredArticle) -> Bool {
        var success = true
        Database.si.write.inDatabase { db in
            do {
                let table = tableName(repository: self)
                let query = "REPLACE INTO \(table) VALUES (?, ?, ?)"
                try db.executeUpdate(query, article.articleId, article.serverId, article.name)
            } catch {
                success = false
                printError(error)
            }
        }
        return success
    }
}

extension IgnoredArticle: PersistedItem {
    class func item(itemId: Int64, serverId: Int64, repository: ItemRepository = IgnoredArticleRepository.si) -> Item? {
        return (repository as? IgnoredArticleRepository)?.article(articleId: itemId, serverId: serverId)
    }
    
    var isPersisted: Bool {
        return repository.isPersisted(article: self)
    }
    
    var hasCachedSubItems: Bool {
        return false
    }
    
    @discardableResult func replace() -> Bool {
        return repository.replace(article: self)
    }
    
    @discardableResult func cache() -> Bool {
        return repository.replace(article: self)
    }
    
    @discardableResult func delete() -> Bool {
        return repository.delete(article: self)
    }
    
    @discardableResult func deleteCache() -> Bool {
        return repository.delete(article: self)
    }
    
    func loadSubItems() {
    }
}
