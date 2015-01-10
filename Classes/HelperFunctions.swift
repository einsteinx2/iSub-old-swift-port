//
//  HelperFunctions.swift
//  iSub
//
//  Created by Benjamin Baron on 1/10/15.
//  Copyright (c) 2015 Ben Baron. All rights reserved.
//

import Foundation

// MARK: - Section Indexes -

public class ISMSSectionIndex {
    var firstIndex: Int
    var sectionCount: Int
    var letter: Character
    
    init (firstIndex: Int, sectionCount: Int, letter: Character) {
        self.firstIndex = firstIndex
        self.sectionCount = sectionCount
        self.letter = letter
    }
}

public func sectionIndexesForItems(items: [ISMSItem]) -> [ISMSSectionIndex] {
    func isDigit(c: Character) -> Bool {
        let cset = NSCharacterSet.decimalDigitCharacterSet()
        let s = String(c)
        let ix = s.startIndex
        let ix2 = s.endIndex
        let result = s.rangeOfCharacterFromSet(cset, options: nil, range: ix..<ix2)
        return result != nil
    }
    
    func ignoredArticles() -> [String] {
        var ignoredArticles = [String]()
        
        let database = DatabaseSingleton.sharedInstance() as DatabaseSingleton
        database.songModelDbQueue.inDatabase({ (db: FMDatabase!) in
            let result = db.executeQuery("SELECT name FROM ignoredArticles", withArgumentsInArray:[])
            while result.next() {
                ignoredArticles.append(result.stringForColumnIndex(0))
            }
            result.close()
        })
        
        return ignoredArticles
    }
    
    func nameIgnoringArticles(#name: String, #articles: [String]) -> String {
        if articles.count > 0 {
            for article in articles {
                let articlePlusSpace = article + " "
                if name.hasPrefix(articlePlusSpace) {
                    let index = advance(name.startIndex, countElements(articlePlusSpace))
                    return name.substringFromIndex(index)
                }
            }
        }
        
        return (name as NSString).stringWithoutIndefiniteArticle()
    }

    var sectionIndexes: [ISMSSectionIndex] = []
    var lastFirstLetter: Character? = nil
    let articles = ignoredArticles()
    
    var index: Int = 0
    var count: Int = 0
    for item in items {
        let name = nameIgnoringArticles(name: item.itemName, articles: articles)
        var firstLetter = Array(name.uppercaseString)[0]
        
        // Sort digits to the end in a single "#" section
        if isDigit(firstLetter) {
            firstLetter = "#"
        }
        
        if lastFirstLetter == nil {
            lastFirstLetter = firstLetter
            sectionIndexes.append(ISMSSectionIndex(firstIndex: 0, sectionCount: 0, letter: firstLetter))
        }
        
        if lastFirstLetter != firstLetter {
            lastFirstLetter = firstLetter
            
            if var last = sectionIndexes.last {
                last.sectionCount = count
                sectionIndexes.removeLast()
                sectionIndexes.append(last)
            }
            count = 0
            
            sectionIndexes.append(ISMSSectionIndex(firstIndex: index, sectionCount: 0, letter: firstLetter))
        }
        
        index++
        count++
    }
    
    if var last = sectionIndexes.last {
        last.sectionCount = count
        sectionIndexes.removeLast()
        sectionIndexes.append(last)
    }
    
    return sectionIndexes
}

// MARK: - Play Songs -

private func _playAll(#songs: [ISMSSong], #shuffle: Bool, #playIndex: Int) {
    // TODO: Implement
    fatalError("_playAll not implemented yet");
}

public func playAll(#songs: [ISMSSong], #playIndex: Int) {
    _playAll(songs: songs, shuffle: false, playIndex: playIndex)
}

public func shuffleAll(#songs: [ISMSSong], #playIndex: Int) {
    _playAll(songs: songs, shuffle: true, playIndex: playIndex)
}