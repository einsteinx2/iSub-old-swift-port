//
//  String.swift
//  iSub
//
//  Created by Benjamin Baron on 12/21/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation
import CoreText

// http://stackoverflow.com/a/26775912/299262
extension String {
    var length: Int {
        return self.characters.count
    }
    
    subscript (i: Int) -> String {
        return self[Range(i ..< i + 1)]
    }
    
    func substring(from: Int) -> String {
        return self[Range(min(from, length) ..< length)]
    }
    
    func substring(to: Int) -> String {
        return self[Range(0 ..< max(0, to))]
    }
    
    subscript (r: Range<Int>) -> String {
        let range = Range(uncheckedBounds: (lower: max(0, min(length, r.lowerBound)),
                                            upper: min(length, max(0, r.upperBound))))
        let start = index(startIndex, offsetBy: range.lowerBound)
        let end = index(start, offsetBy: range.upperBound - range.lowerBound)
        return String(self[Range(start ..< end)])
    }
}

extension String {
    static func random(_ length: Int = 32) -> String {
        let chars = Array<Character>("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789".characters)
        let charsCount = UInt32(chars.count)
        
        var string = ""
        for _ in 0..<length {
            let index = Int(arc4random_uniform(charsCount))
            let randomChar = chars[index]
            string.append(randomChar)
        }
        
        return string
    }
    
    var md5: String {
        return self.data(using: .utf8)!.md5
    }
    
    var sha1: String {
        return self.data(using: .utf8)!.sha1
    }
    
    var sha256: String {
        return self.data(using: .utf8)!.sha256
    }
}

public extension String {
    
    // By default, the URLQueryAllowedCharacterSet is meant to allow encoding of entire query strings. This is
    // a problem because it won't handle, for example, a password containing an & character. So we need to remove
    // those characters from the character set. Then the stringByAddingPercentEncodingWithAllowedCharacters method
    // will work as expected.
    static public var URLQueryEncodedValueAllowedCharacters: CharacterSet = {
        var charSet = CharacterSet.urlQueryAllowed
        charSet.remove(charactersIn: "?&=@+/'")
        return charSet
    }()
    
    // Used to encode individual query parameters
    var URLQueryParameterEncodedValue: String {
        return self.addingPercentEncoding(withAllowedCharacters: String.URLQueryEncodedValueAllowedCharacters) ?? self
    }
    
    // Used to encode entire query strings
    var URLQueryStringEncodedValue: String {
        return self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) ?? self
    }
    
    var clean: String {
        return self.htmlUnescape().removingPercentEncoding ?? self
    }
}

public extension String {
    func size(font: UIFont, targetSize: CGSize = CGSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)) -> CGSize {
        let attributedString = NSAttributedString(string: self, attributes: [NSAttributedStringKey.font: font])
        let framesetter = CTFramesetterCreateWithAttributedString(attributedString)
        let size = CTFramesetterSuggestFrameSizeWithConstraints(framesetter, CFRangeMake(0, attributedString.length), nil, targetSize, nil);
        
        return size
    }
}
