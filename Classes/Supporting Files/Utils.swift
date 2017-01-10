//
//  Utils.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

public func printError(_ error: Any, file: String = #file, line: Int = #line, function: String = #function) {
    let fileName = NSURL(fileURLWithPath: file).deletingPathExtension?.lastPathComponent
    let functionName = function.components(separatedBy: "(").first
    
    if let fileName = fileName, let functionName = functionName {
        print("[\(fileName):\(line) \(functionName)] \(error)")
    } else {
        print("[\(file):\(line) \(function)] \(error)")
    }
}

// Returns NSNull if the input is nil. Useful for things like db queries.
// TODO: Figure out why FMDB in Swift won't take nil arguments in var args functions
public func n2N(_ nullableObject: Any?) -> Any {
    return nullableObject == nil ? NSNull() : nullableObject!
}

// Backfill for iOS 9
enum TapticFeedbackStyle : Int {
    case light
    case medium
    case heavy
}

func tapticFeedback(style: TapticFeedbackStyle = .medium) {
    let deviceType = UIDevice.current.deviceType
    if deviceType == .iPhone7 || deviceType == .iPhone7Plus {
        if #available(iOS 10, *) {
            let convertedStyle = UIImpactFeedbackStyle(rawValue: style.rawValue)!
            let feedbackGenerator = UIImpactFeedbackGenerator(style: convertedStyle)
            feedbackGenerator.impactOccurred()
            return
        }
    }
    
    // Play undocumented peek sound
    AudioServicesPlaySystemSound(1519)
}

func clamp<T: Comparable>(value: T, lower: T, upper: T) -> T {
    return min(max(value, lower), upper)
}

// Generic number type: http://stackoverflow.com/a/25578624/299262
protocol NumericType {
    static func +(lhs: Self, rhs: Self) -> Self
    static func -(lhs: Self, rhs: Self) -> Self
    static func *(lhs: Self, rhs: Self) -> Self
    static func /(lhs: Self, rhs: Self) -> Self
    static func %(lhs: Self, rhs: Self) -> Self
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
