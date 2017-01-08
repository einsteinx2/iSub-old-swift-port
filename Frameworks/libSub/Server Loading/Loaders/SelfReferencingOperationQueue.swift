//
//  SelfReferencingOperationQueue.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

class SelfReferencingOperationQueue: OperationQueue {
    
    fileprivate var selfRef: SelfReferencingOperationQueue?
    
    override init() {
        super.init()
        self.addObserver(self, forKeyPath: "operations", context: nil)
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: "operations")
    }
    
    override func addOperation(_ op: Operation) {
        if selfRef == nil {
            selfRef = self
        }
        
        super.addOperation(op)
    }
    
    override func addOperation(_ block: @escaping () -> Void) {
        if selfRef == nil {
            selfRef = self
        }
        
        super.addOperation(block)
    }
    
    override func addOperations(_ ops: [Operation], waitUntilFinished wait: Bool) {
        if selfRef == nil {
            selfRef = self
        }
        
        super.addOperations(ops, waitUntilFinished: wait)
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if let object = object as? SelfReferencingOperationQueue, object == self && keyPath == "operations" {
            selfRef = nil;
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
