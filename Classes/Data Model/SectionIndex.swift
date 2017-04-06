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
    
    static func sectionIndexes(forNames names: [String]?) -> [SectionIndex] {
        guard let names = names else {
            return []
        }
        
        var sectionIndexes: [SectionIndex] = []
        var lastFirstLetter: String?
        let articles = Database.si.ignoredArticles
        
        var index: Int = 0
        var count: Int = 0
        for name in names {
            if name.length > 0 {
                let nameIgnoringArticles = Database.si.name(name, ignoringArticles: articles).uppercased()
                let firstScalar = nameIgnoringArticles.unicodeScalars.first
                var firstLetter = nameIgnoringArticles[0]
                
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
    
    static func sectionIndexes(forItems items: [Item]?) -> [SectionIndex] {
        guard let items = items else {
            return []
        }
        
        let names = items.map({$0.itemName})
        return sectionIndexes(forNames: names)
    }
    
    static func sectionIndexes(forCount count: Int) -> [SectionIndex] {
        guard count > 50 else {
            return []
        }
        
        var sectionIndexes: [SectionIndex] = []
        
        let clampedCount = clamp(value: count, lower: 50, upper: 1000)
        let sectionCountDivisor = convertToRange(number: clampedCount, inputMin: 50, inputMax: 1000, outputMin: 5, outputMax: 40)
        
        let sectionCount = count / sectionCountDivisor
        let sections = count / sectionCount
        for i in 0..<sections {
            let index = SectionIndex(firstIndex: i * sectionCount, sectionCount: sectionCount, letter: "•")
            sectionIndexes.append(index)
        }
        
        return sectionIndexes
    }
}
