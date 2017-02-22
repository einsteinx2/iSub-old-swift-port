//
//  SafeNumberCasting.swift
//  iSub
//
//  Created by Benjamin Baron on 2/22/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension UInt64 {
    init?(exactly value: Double) {
        if value >= Double(UInt64.min) && value <= Double(UInt64.max) {
            self = UInt64(value)
        }
        return nil
    }
}

extension Int64 {
    init?(exactly value: Double) {
        if value >= Double(Int64.min) && value <= Double(Int64.max) {
            self = Int64(value)
        }
        return nil
    }
}

extension UInt32 {
    init?(exactly value: Double) {
        if value >= Double(UInt32.min) && value <= Double(UInt32.max) {
            self = UInt32(value)
        }
        return nil
    }
}

extension Int32 {
    init?(exactly value: Double) {
        if value >= Double(Int32.min) && value <= Double(Int32.max) {
            self = Int32(value)
        }
        return nil
    }
}

extension UInt {
    init?(exactly value: Double) {
        if value >= Double(UInt.min) && value <= Double(UInt.max) {
            self = UInt(value)
        }
        return nil
    }
}

extension Int {
    init?(exactly value: Double) {
        if value >= Double(Int.min) && value <= Double(Int.max) {
            self = Int(value)
        }
        return nil
    }
}
