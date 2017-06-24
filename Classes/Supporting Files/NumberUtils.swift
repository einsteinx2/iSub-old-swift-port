//
//  NumberUtils.swift
//  iSub
//
//  Created by Benjamin Baron on 4/6/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

func clamp<T: Comparable>(value: T, lower: T, upper: T) -> T {
    return min(max(value, lower), upper)
}

// Generic number type: http://stackoverflow.com/a/25578624/299262
protocol NumericType {
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    static func *(lhs: Self, rhs: Self) -> Self
    static func /(lhs: Self, rhs: Self) -> Self
    init(_ v: Int)
}
extension CGFloat : NumericType { }
extension Double  : NumericType { }
extension Float   : NumericType { }
extension Int     : NumericType { }
extension Int8    : NumericType { }
extension Int16   : NumericType { }
extension Int32   : NumericType { }
extension Int64   : NumericType { }
extension UInt    : NumericType { }
extension UInt8   : NumericType { }
extension UInt16  : NumericType { }
extension UInt32  : NumericType { }
extension UInt64  : NumericType { }

func convertToRange<T: NumericType>(number: T, inputMin: T, inputMax: T, outputMin: T, outputMax: T) -> T {
    let inputRange = inputMax - inputMin
    let outputRange = outputMax - outputMin
    let adjusted = (((number - inputMin) * outputRange) / inputRange) + outputMin
    return adjusted
}
