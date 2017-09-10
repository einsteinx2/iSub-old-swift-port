//
//  HLSSegment.swift
//  iSub
//
//  Created by Benjamin Baron on 9/10/17.
//  Copyright © 2017 Benjamin Baron. All rights reserved.
//
// Loosely based on the example code here: https://github.com/kencool/KSHLSPlayer
//

import Foundation

final class HLSSegment: Equatable {
    let url: URL
    let fileName: String
    let duration: Double
    let sequence: Int
    
    init(url: URL, fileName: String, duration: Double, sequence: Int) {
        self.url = url
        self.fileName = fileName
        self.duration = duration
        self.sequence = sequence
    }
    
    static func ==(lhs: HLSSegment, rhs: HLSSegment) -> Bool {
        return lhs.url == rhs.url && lhs.duration == rhs.duration && lhs.sequence == rhs.sequence
    }
}
