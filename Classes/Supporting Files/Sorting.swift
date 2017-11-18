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
    
    static func name(_ name: String, ignoringArticles articles: [String] = ignoredArticles) -> String {
        for article in articles {
            // See if the string starts with this article, note the space after each article to reduce false positives
            if name.lowercased().hasPrefix("\(article) ") {
                // Make sure we don't mess with it if there's nothing after the article
                if name.count > article.count + 1 {
                    // Move the article to the end after a comma
                    //return "\(name.substring(from: article.length + 1)), \(name.substring(to: article.length))"
                    
                    // We don't need the above format right now, so saving cycles by just returning the name
                    return name.substring(from: article.count + 1)
                }
            }
        }
        
        // Does not contain an article
        return name
    }
    
    static func subsonicSorted<T: Item>(items: [T], ignoringArticles articles: [String] = ignoredArticles) -> [T] {
        return items.sorted {
            var name1 = Sorting.name($0.itemName.lowercased(), ignoringArticles: articles)
            name1 = name1.replacingOccurrences(of: " ", with: "")
            name1 = name1.replacingOccurrences(of: "-", with: "")
            
            var name2 = Sorting.name($1.itemName.lowercased(), ignoringArticles: articles)
            name2 = name2.replacingOccurrences(of: " ", with: "")
            name2 = name2.replacingOccurrences(of: "-", with: "")
            
            return name1 < name2
        }
    }
}
