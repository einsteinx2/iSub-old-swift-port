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

func BytesForSecondsAtBitRate(seconds: Int, bitRate: Int) -> Int64 {
    return (Int64(bitRate) / 8) * 1024 * Int64(seconds)
}

let ISMSHeaderColor = UIColor(red: 200.0/255.0, green: 200.0/255.0, blue: 206.0/255.0, alpha: 1.0)
let ISMSHeaderTextColor = UIColor(red: 77.0/255.0, green: 77.0/255.0, blue: 77.0/255.0, alpha: 1.0)
let ISMSHeaderButtonColor = UIColor(red: 0.0, green: 122.0/255.0, blue: 1.0, alpha: 1.0)

let ISMSiPadBackgroundColor = ISMSHeaderColor
let ISMSiPadCornerRadius = 5.0

let CellHeight: CGFloat = 50.0
let CellHeaderHeight: CGFloat = 20.0

let documentsPath = NSSearchPathForDirectoriesInDomains(.documentDirectory, .userDomainMask, true)[0]
let cachesPath = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)[0]
let songCachePath = documentsPath + "/songCache"
let tempCachePath = cachesPath + "/tempCache"
let imageCachePath = documentsPath + "/imageCache"
