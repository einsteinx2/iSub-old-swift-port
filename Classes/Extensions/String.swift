//
//  String.swift
//  iSub
//
//  Created by Benjamin Baron on 12/21/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import Foundation

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
        return self[Range(start ..< end)]
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
    static fileprivate var queryCharSet: CharacterSet = CharacterSet.urlQueryAllowed
    static fileprivate var queryCharSetToken: Int = 0
    static public var URLQueryEncodedValueAllowedCharacters: CharacterSet = {
        let mutableCharSet = (queryCharSet as NSCharacterSet).mutableCopy() as! NSMutableCharacterSet
        mutableCharSet.removeCharacters(in: "?&=@+/'")
        queryCharSet = mutableCharSet as CharacterSet
        return queryCharSet
    }()
    
    // Used to encode individual query parameters
    var URLQueryParameterEncodedValue: String {
        if let encodedValue = self.addingPercentEncoding(withAllowedCharacters: String.URLQueryEncodedValueAllowedCharacters) {
            return encodedValue
        } else {
            return self
        }
    }
    
    // Used to encode entire query strings
    var URLQueryStringEncodedValue: String {
        if let encodedValue = self.addingPercentEncoding(withAllowedCharacters: CharacterSet.urlQueryAllowed) {
            return encodedValue
        } else {
            return self
        }
    }
}
