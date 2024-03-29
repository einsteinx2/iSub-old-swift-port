//
//  DispatchQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

// Convenience functions for running things asynchronously on the main thread

func async(_ work: @escaping @convention(block) () -> Swift.Void) {
    DispatchQueue.main.async { work() }
}

public func async(after timeInterval: TimeInterval, execute work: @escaping @convention(block) () -> Swift.Void) {
    DispatchQueue.main.async(after: timeInterval) { work() }
}

extension DispatchQueue {
    // Work that is interacting with the user, such as operating on the main thread, refreshing the user interface, or performing animations. If the work doesn’t happen quickly, the user interface may appear frozen. Focuses on responsiveness and performance.
    // Work is virtually instantaneous.
    static var userInteractive: DispatchQueue { return DispatchQueue.global(qos: .userInteractive) }
    
    // Work that the user has initiated and requires immediate results, such as opening a saved document or performing an action when the user clicks something in the user interface. The work is required in order to continue user interaction. Focuses on responsiveness and performance.
    // Work is nearly instantaneous, such as a few seconds or less.
    static var userInitiated: DispatchQueue   { return DispatchQueue.global(qos: .userInitiated) }
    
    // Work that may take some time to complete and doesn’t require an immediate result, such as downloading or importing data. Utility tasks typically have a progress bar that is visible to the user. Focuses on providing a balance between responsiveness, performance, and energy efficiency.
    // Work takes a few seconds to a few minutes.
    static var utility: DispatchQueue         { return DispatchQueue.global(qos: .utility) }
    
    // Work that operates in the background and isn’t visible to the user, such as indexing, synchronizing, and backups. Focuses on energy efficiency.
    // Work takes significant time, such as minutes or hours.
    static var background: DispatchQueue      { return DispatchQueue.global(qos: .background) }
    
    public func async(after timeInterval: TimeInterval, execute work: @escaping @convention(block) () -> Swift.Void) {
        let milliseconds = Int(timeInterval * 1000)
        let deadline = DispatchTime.now() + .milliseconds(milliseconds)
        asyncAfter(deadline: deadline, execute: work)
    }
    
    public func async(afterWall timeInterval: TimeInterval, execute work: @escaping @convention(block) () -> Swift.Void) {
        let milliseconds = Int(timeInterval * 1000)
        let deadline = DispatchWallTime.now() + .milliseconds(milliseconds)
        asyncAfter(wallDeadline: deadline, execute: work)
    }

    public func async(after timeInterval: TimeInterval, execute: DispatchWorkItem) {
        let milliseconds = Int(timeInterval * 1000)
        let deadline = DispatchTime.now() + .milliseconds(milliseconds)
        asyncAfter(deadline: deadline, execute: execute)
    }
    
    public func asyncAfter(afterWall timeInterval: TimeInterval, execute: DispatchWorkItem) {
        let milliseconds = Int(timeInterval * 1000)
        let deadline = DispatchWallTime.now() + .milliseconds(milliseconds)
        asyncAfter(wallDeadline: deadline, execute: execute)
    }
}
