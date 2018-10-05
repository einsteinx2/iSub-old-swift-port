//
//  String.swift
//  iSub
//
//  Created by Benjamin Baron on 12/21/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation
import CoreText
import HTMLEntities

// http://stackoverflow.com/a/26775912/299262
extension String {
    subscript (i: Int) -> String {
        return String(self[index(startIndex, offsetBy: i)])
    }
    
    func substring(from: Int) -> String {
        return self[from ..< count]
    }
    
    func substring(to: Int) -> String {
        return self[0 ..< max(0, to)]
    }
    
    subscript (bounds: CountableRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ..< end])
    }
    
    subscript (bounds: CountableClosedRange<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[start ... end])
    }
    
    subscript (bounds: CountablePartialRangeFrom<Int>) -> String {
        let start = index(startIndex, offsetBy: bounds.lowerBound)
        let end = index(endIndex, offsetBy: -1)
        return String(self[start ... end])
    }
    
    subscript (bounds: PartialRangeThrough<Int>) -> String {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[startIndex ... end])
    }
    
    subscript (bounds: PartialRangeUpTo<Int>) -> String {
        let end = index(startIndex, offsetBy: bounds.upperBound)
        return String(self[startIndex ..< end])
    }
}

extension String {
    static func random(_ length: Int = 32) -> String {
        let chars = Array("abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789")
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
