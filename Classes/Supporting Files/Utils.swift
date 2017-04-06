//
//  Utils.swift
//  LibSub
//
//  Created by Benjamin Baron on 3/9/16.
//
//

import Foundation

// Returns NSNull if the input is nil. Useful for things like db queries.
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

