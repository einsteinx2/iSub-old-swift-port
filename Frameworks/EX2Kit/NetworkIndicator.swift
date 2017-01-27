//
//  NetworkIndicator.swift
//  iSub
//
//  Created by Benjamin Baron on 1/26/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

final class NetworkIndicator {
    fileprivate static let lock = SpinLock()
    fileprivate static var counter = 0
    
    static func usingNetwork() {
        lock.synchronized {
            counter += 1
            UIApplication.shared.isNetworkActivityIndicatorVisible = true
        }
    }
    
    static func doneUsingNetwork() {
        lock.synchronized {
            if counter > 0 {
                counter -= 1
                if counter == 0 {
                    UIApplication.shared.isNetworkActivityIndicatorVisible = false
                }
            }
        }
    }
    
    static func goingOffline() {
        lock.synchronized {
            if counter > 0 {
                counter = 0
                UIApplication.shared.isNetworkActivityIndicatorVisible = false
            }
        }
    }
}
