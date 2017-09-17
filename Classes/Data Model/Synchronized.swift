//
//  Lockable.swift
//  iSub
//
//  Created by Benjamin Baron on 1/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//
//  ------------------------------------------------
//  From https://gist.github.com/kristopherjohnson/d12877ee9a901867f599
//

import Foundation
import Darwin

protocol TryLockable: NSLocking {
    func `try`() -> Bool
}
extension NSLock: TryLockable {}
extension NSRecursiveLock: TryLockable {}
extension NSConditionLock: TryLockable {}

protocol BeforeDateLockable: NSLocking {
    func lock(before limit: Date) -> Bool
}
extension NSLock: BeforeDateLockable {}
extension NSRecursiveLock: BeforeDateLockable {}
extension NSConditionLock: BeforeDateLockable {}

extension NSLocking {
    func synchronized(_ execute: () -> ()) {
        lock()
        execute()
        unlock()
    }
    
    func synchronizedResult<T>(_ execute: () -> T) -> T {
        lock()
        let result = execute()
        unlock()
        return result
    }
}

extension TryLockable {
    func trySynchronized(_ execute: () -> ()) -> Bool {
        if !`try`() {
            return false
        }
        execute()
        unlock()
        return true
    }
}

extension BeforeDateLockable {
    func trySynchronized(before: Date, execute: () -> ()) -> Bool {
        if !lock(before: before) {
            return false
        }
        unlock()
        return true
    }
}

// OSSpinLock is much faster than other options when there is infrequent contention
// https://gist.github.com/steipete/36350a8a60693d440954b95ea6cbbafc
class SpinLock: TryLockable {
    private var spinLock = OS_SPINLOCK_INIT
    
    func lock() {
        OSSpinLockLock(&spinLock)
    }
    
    func unlock() {
        OSSpinLockUnlock(&spinLock)
    }
    
    func `try`() -> Bool {
        return OSSpinLockTry(&spinLock)
    }
}

/*
// OSSpinLock is deprecated in iOS 10, so eventually move to os_unfair_lock
@available (iOS 10.0, *)
class UnfairLock: TryLockable {
    private var unfairLock = OS_UNFAIR_LOCK_INIT
 
    func lock() {
        os_unfair_lock_lock(&unfairLock)
    }
 
    func unlock() {
        os_unfair_lock_unlock(&unfairLock)
    }
 
    func `try`() -> Bool {
        os_unfair_lock_trylock(&unfairLock)
    }
}*/

