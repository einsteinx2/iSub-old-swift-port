//
//  Defines.swift
//  iSub
//
//  Created by Benjamin Baron on 12/15/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

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
    
    let screenWidth = UIScreen.main.bounds.size.width
    let percent = (screenWidth - BaseWidth)/screenWidth
    let normalizedValue = value * (1 + percent) * multiplier
    let minValue = min(normalizedValue, value + maxDelta) //capped by a max value if needed
    return ceil(minValue) // Return whole numbers
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
