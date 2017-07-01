//
//  JGUserDefault.swift
//
//  Created by Jeff on 12/17/15.
//  Copyright © 2015 Jeff Greenberg. All rights reserved.
//

import Foundation

/// Generic struct to retrieve & save to NSUserDefaults
public struct JGUserDefault<T> {
    fileprivate let key: String
    fileprivate let defaultValue: T
    
    public init(key: String, defaultValue: T) {
        self.key = key
        self.defaultValue = defaultValue
    }
    
    public func value(_ storage: UserDefaults = UserDefaults.standard) -> T {
        return (storage.object(forKey: self.key) as? T ?? self.defaultValue)
    }
    
    public func save(_ newValue: T, storage: UserDefaults = UserDefaults.standard) {
        storage.set((newValue as AnyObject), forKey: self.key)
    }
}
