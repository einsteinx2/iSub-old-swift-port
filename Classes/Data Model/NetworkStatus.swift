//
//  WifiReachability.swift
//  iSub
//
//  Created by Benjamin Baron on 1/4/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import Reachability

@objc class NetworkStatus: NSObject {
    let reachability = Reachability()
    
    var isReachable: Bool {
        if let reachability = reachability {
            return reachability.isReachable
        }
        return true
    }
    
    var isReachableWifi: Bool {
        if let reachability = reachability {
            return reachability.isReachableViaWiFi
        }
        return false
    }
    
    func startMonitoring() {
        reachability?.whenReachable = becameReachable
        reachability?.whenUnreachable = becameUnreachable
        do {
            try reachability?.startNotifier()
        } catch {
            //log.error("Unable to start Reachability notifier")
        }
    }
    
    func stopMonitoring() {
        reachability?.stopNotifier()
    }
    
    fileprivate func becameReachable(reachability: Reachability) {
        NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ReachabilityChanged)
    }
    
    fileprivate func becameUnreachable(reachability: Reachability) {
        NotificationCenter.postNotificationToMainThread(withName: ISMSNotification_ReachabilityChanged)
    }
}
