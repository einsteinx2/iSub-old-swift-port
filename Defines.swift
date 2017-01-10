//
//  Defines.swift
//  iSub
//
//  Created by Benjamin Baron on 12/15/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit
import Device

func IS_IPAD() -> Bool
{
    return UIDevice.current.userInterfaceIdiom == .pad
}

func ISMSRegularFont(_ size: CGFloat) -> UIFont
{
    return UIFont(name: "HelveticaNeue", size: size)!
}

func ISMSBoldFont(_ size: CGFloat) -> UIFont
{
    return UIFont(name: "HelveticaNeue-Bold", size: size)!
}

private let BaseWidth : CGFloat = 320
func ISMSNormalize(_ value: CGFloat, multiplier: CGFloat = 1, maxDelta: CGFloat = 1024) -> CGFloat {
    if UIDevice.current.userInterfaceIdiom == UIUserInterfaceIdiom.pad {
        return value
    }

    let screenWidth = portraitScreenSize.width
    let percent = (screenWidth - BaseWidth)/screenWidth
    let normalizedValue = value * (1 + percent) * multiplier
    let minValue = min(normalizedValue, value + maxDelta) //capped by a max value if needed
    return ceil(minValue) // Return whole numbers
}

var portraitScreenSize: CGSize {
    let screenSize = UIScreen.main.bounds.size
    let width = min(screenSize.width, screenSize.height)
    let height = max(screenSize.width, screenSize.height)
    return CGSize(width: width, height: height)
}

func BytesForSecondsAtBitrate(_ seconds: Int, bitrate: Int) -> Int {
    return (bitrate / 8) * 1024 * seconds
}

let ISMSHeaderColor = UIColor(red: 200.0/255.0, green: 200.0/255.0, blue: 206.0/255.0, alpha: 1.0)
let ISMSHeaderTextColor = UIColor(red: 77.0/255.0, green: 77.0/255.0, blue: 77.0/255.0, alpha: 1.0)
let ISMSHeaderButtonColor = UIColor(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0)

let ISMSArtistFont = ISMSRegularFont(16)
let ISMSAlbumFont = ISMSRegularFont(16)
let ISMSSongFont = ISMSRegularFont(16)

let ISMSiPadBackgroundColor = ISMSHeaderColor
let ISMSiPadCornerRadius = 5.0

let ISMSFolderCellHeight: CGFloat = 50.0
let ISMSSubfolderCellHeight: CGFloat = 50.0
let ISMSSongCellHeight: CGFloat = 50.0
let ISMSAlbumCellHeight: CGFloat = 50.0
let ISMSArtistCellHeight: CGFloat = 50.0
let ISMSCellHeaderHeight: CGFloat = 20.0

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
