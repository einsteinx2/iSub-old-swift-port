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

/// Protocol for NSLocking objects that also provide try()
public protocol TryLockable: NSLocking {
    func `try`() -> Bool
}

// These Cocoa classes have tryLock()
extension NSLock: TryLockable {}
extension NSRecursiveLock: TryLockable {}
extension NSConditionLock: TryLockable {}


/// Protocol for NSLocking objects that also provide lock(before limit: Date)
public protocol BeforeDateLockable: NSLocking {
    func lock(before limit: Date) -> Bool
}

// These Cocoa classes have lockBeforeDate()
extension NSLock: BeforeDateLockable {}
extension NSRecursiveLock: BeforeDateLockable {}
extension NSConditionLock: BeforeDateLockable {}


/// Use an NSLocking object as a mutex for a critical section of code
public func synchronized<L: NSLocking>(lockable: L, criticalSection: () -> ()) {
    lockable.lock()
    criticalSection()
    lockable.unlock()
}

/// Use an NSLocking object as a mutex for a critical section of code that returns a result
public func synchronizedResult<L: NSLocking, T>(lockable: L, criticalSection: () -> T) -> T {
    lockable.lock()
    let result = criticalSection()
    lockable.unlock()
    return result
}

/// Use a TryLockable object as a mutex for a critical section of code
///
/// Return true if the critical section was executed, or false if tryLock() failed
public func trySynchronized<L: TryLockable>(lockable: L, criticalSection: () -> ()) -> Bool {
    if !lockable.try() {
        return false
    }
    criticalSection()
    lockable.unlock()
    return true
}

/// Use a BeforeDateLockable object as a mutex for a critical section of code
///
/// Return true if the critical section was executed, or false if lockBeforeDate() failed
public func synchronizedBeforeDate<L: BeforeDateLockable>(limit: Date, lockable: L, criticalSection: () -> ()) -> Bool {
    if !lockable.lock(before: limit) {
        return false
    }
    criticalSection()
    lockable.unlock()
    return true
}
