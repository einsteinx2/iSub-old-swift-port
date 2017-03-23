//
//  Utils.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

// Returns NSNull if the input is nil. Useful for things like db queries.
// TODO: Figure out why FMDB in Swift won't take nil arguments in var args functions
func n2N(_ nullableObject: Any?) -> Any {
    return nullableObject ?? NSNull()
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

// Immutable

func bridge<T : AnyObject>(obj : T) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passUnretained(obj).toOpaque())
}

func bridge<T : AnyObject>(ptr : UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

func bridgeRetained<T : AnyObject>(obj : T) -> UnsafeRawPointer {
    return UnsafeRawPointer(Unmanaged.passRetained(obj).toOpaque())
}

func bridgeTransfer<T : AnyObject>(ptr : UnsafeRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}

// Mutable

func bridge<T : AnyObject>(obj : T) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(mutating: UnsafeRawPointer(Unmanaged.passUnretained(obj).toOpaque()))
}

func bridge<T : AnyObject>(ptr : UnsafeMutableRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeUnretainedValue()
}

func bridgeRetained<T : AnyObject>(obj : T) -> UnsafeMutableRawPointer {
    return UnsafeMutableRawPointer(mutating: UnsafeRawPointer(Unmanaged.passRetained(obj).toOpaque()))
}

func bridgeTransfer<T : AnyObject>(ptr : UnsafeMutableRawPointer) -> T {
    return Unmanaged<T>.fromOpaque(ptr).takeRetainedValue()
}
