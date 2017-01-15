//
//  SectionIndex.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

struct SectionIndex {
    var firstIndex: Int
    var sectionCount: Int
    var letter: String
    
    init (firstIndex: Int, sectionCount: Int, letter: String) {
        self.firstIndex = firstIndex
        self.sectionCount = sectionCount
        self.letter = letter
    }
    
    static func sectionIndexesForItems(_ items: [ISMSItem]?) -> [SectionIndex] {
        guard let items = items else {
            return []
        }
        
        var sectionIndexes: [SectionIndex] = []
        var lastFirstLetter: String?
        let articles = DatabaseSingleton.si().ignoredArticles()
        
        var index: Int = 0
        var count: Int = 0
        for item in items {
            if let itemName = item.itemName, itemName.characters.count > 0 {
                let name = DatabaseSingleton.si().name(itemName, ignoringArticles: articles).uppercased()
                let firstScalar = name.unicodeScalars.first
                var firstLetter = name[0]
                
                if let firstScalar = firstScalar, !CharacterSet.letters.contains(firstScalar) {
                    firstLetter = "#"
                }
                
                if lastFirstLetter == nil {
                    lastFirstLetter = firstLetter
                    sectionIndexes.append(SectionIndex(firstIndex: 0, sectionCount: 0, letter: firstLetter))
                }
                
                if lastFirstLetter != firstLetter {
                    lastFirstLetter = firstLetter
                    
                    if var last = sectionIndexes.last {
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
        
        if var last = sectionIndexes.last {
            last.sectionCount = count
            sectionIndexes.removeLast()
            sectionIndexes.append(last)
        }
        
        return sectionIndexes
    }
}
