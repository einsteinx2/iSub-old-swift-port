//
//  SectionIndex.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

open class SectionIndex {
    open var firstIndex: Int
    open var sectionCount: Int
    open var letter: String
    
    init (firstIndex: Int, sectionCount: Int, letter: String) {
        self.firstIndex = firstIndex
        self.sectionCount = sectionCount
        self.letter = letter
    }
    
    open class func sectionIndexesForItems(_ items: [ISMSItem]?) -> [SectionIndex] {
        guard let items = items else {
            return []
        }
        
        func isDigit(_ s: String) -> Bool {
            let cset = CharacterSet.decimalDigits
            let ix = s.startIndex
            let ix2 = s.endIndex
            let result = s.rangeOfCharacter(from: cset, options: [], range: ix..<ix2)
            return result != nil
        }
        
        func ignoredArticles() -> [String] {
            var ignoredArticles = [String]()
            
            DatabaseSingleton.sharedInstance().songModelReadDbPool.inDatabase { db in
                do {
                    let query = "SELECT name FROM ignoredArticles"
                    let result = try db.executeQuery(query)
                    while result.next() {
                        ignoredArticles.append(result.string(forColumnIndex: 0))
                    }
                    result.close()
                } catch {
                    printError(error)
                }
            }
            
            return ignoredArticles
        }
        
        func nameIgnoringArticles(name: String, articles: [String]) -> String {
            if articles.count > 0 {
                for article in articles {
                    let articlePlusSpace = article + " "
                    if name.hasPrefix(articlePlusSpace) {
                        let index = name.characters.index(name.startIndex, offsetBy: articlePlusSpace.characters.count)
                        return name.substring(from: index)
                    }
                }
            }
            
            return (name as NSString).stringWithoutIndefiniteArticle()
        }
        
        var sectionIndexes: [SectionIndex] = []
        var lastFirstLetter: String?
        let articles = ignoredArticles()
        
        var index: Int = 0
        var count: Int = 0
        for item in items {
            if (item.itemName != nil) {
                let name = nameIgnoringArticles(name: item.itemName!, articles: articles)
                var firstLetter = name.uppercased()[0]
                
                // Sort digits to the end in a single "#" section
                if isDigit(firstLetter) {
                    firstLetter = "#"
                }
                
                if lastFirstLetter == nil {
                    lastFirstLetter = firstLetter
                    sectionIndexes.append(SectionIndex(firstIndex: 0, sectionCount: 0, letter: firstLetter))
                }
                
                if lastFirstLetter != firstLetter {
                    lastFirstLetter = firstLetter
                    
                    if let last = sectionIndexes.last {
                        last.sectionCount = count
                        sectionIndexes.removeLast()
                        sectionIndexes.append(last)
                    }
                    count = 0
                    
                    sectionIndexes.append(SectionIndex(firstIndex: index, sectionCount: 0, letter: firstLetter))
                }
                
                index += 1
                count += 1
            }
        }
        
        if let last = sectionIndexes.last {
            last.sectionCount = count
            sectionIndexes.removeLast()
            sectionIndexes.append(last)
        }
        
        return sectionIndexes
    }
}
