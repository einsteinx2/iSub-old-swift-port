//
//  Sorting.swift
//  iSub
//
//  Created by Benjamin Baron on 4/6/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

struct Sorting {
    static var ignoredArticles: [String] {
        var ignoredArticles = [String]()
        
        Database.si.read.inDatabase { db in
            do {
                let result = try db.executeQuery("SELECT name FROM ignoredArticles")
                while result.next() {
                    if let article = result.string(forColumnIndex: 0) {
                        ignoredArticles.append(article)
                    }
                }
                result.close()
            } catch {
                printError(error)
            }
        }
        
        return ignoredArticles
    }
    
    static func name(_ name: String, ignoringArticles articles: [String]) -> String {
        for article in articles {
            let articlePlusSpace = article + " "
            if name.hasPrefix(articlePlusSpace) {
                return name.substring(from: articlePlusSpace.length)
            }
        }
        
        return stringWithoutIndefiniteArticle(name)
    }
    
    static func stringWithoutIndefiniteArticle(_ string: String) -> String {
        let indefiniteArticles = ["the", "los", "las", "les", "el", "la", "le"]
        
        for article in indefiniteArticles {
            // See if the string starts with this article, note the space after each article to reduce false positives
            if string.lowercased().hasPrefix(article + " ") {
                // Make sure we don't mess with it if there's nothing after the article
                if string.length > article.length + 1 {
                    // Move the article to the end after a comma
                    return "\(string.substring(from: article.length + 1)), \(string.substring(to: article.length))"
                }
            }
        }
        
        // Does not contain an article
        return string
    }
    
    static func subsonicSorted<T: Item>(items: [T], ignoredArticles: [String]) -> [T] {
        return items.sorted {
            var name1 = Sorting.name($0.itemName.lowercased(), ignoringArticles: ignoredArticles)
            name1 = name1.replacingOccurrences(of: " ", with: "")
            name1 = name1.replacingOccurrences(of: "-", with: "")
            
            var name2 = Sorting.name($1.itemName.lowercased(), ignoringArticles: ignoredArticles)
            name2 = name2.replacingOccurrences(of: " ", with: "")
            name2 = name2.replacingOccurrences(of: "-", with: "")
            
            return name1 < name2
        }
    }
}
