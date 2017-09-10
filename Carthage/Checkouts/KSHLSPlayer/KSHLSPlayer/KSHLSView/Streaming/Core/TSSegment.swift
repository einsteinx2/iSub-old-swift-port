//
//  TSSegment.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/12.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

public class TSSegment: Equatable {
    
    let url: String
    
    let duration: Double
    
    let sequence: Int
    
    init(url: String, duration: Double, sequence: Int) {
        self.url = url
        self.duration = duration
        self.sequence = sequence
    }
    
    func filename() -> String {
        return (url as NSString).lastPathComponent
    }
    
    /*
    override public func isEqual(object: AnyObject?) -> Bool {
        if let obj = object as? TSSegment {
            //return self.url == obj.url && self.duration == obj.duration && self.sequence == obj.sequence
            return self == obj
        } else {
            return false
        }
    }*/
}

public func ==(lhs: TSSegment, rhs: TSSegment) -> Bool {
    return lhs.url == rhs.url && lhs.duration == rhs.duration && lhs.sequence == rhs.sequence
}