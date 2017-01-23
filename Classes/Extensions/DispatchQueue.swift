//
//  DispatchQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/23/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension DispatchQueue {
    static var background: DispatchQueue {
        return DispatchQueue.global(qos: .background)
    }
    
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
