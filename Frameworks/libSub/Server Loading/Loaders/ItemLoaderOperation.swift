//
//  ItemLoaderOperation.swift
//  iSub
//
//  Created by Benjamin Baron on 1/7/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation
import Async

class ItemLoaderOperation: Operation {
    var loader: ItemLoader
    
    init(loader: ItemLoader) {
        self.loader = loader
        super.init()
    }
    
    override var isAsynchronous: Bool {
        return true
    }
    
    fileprivate var isExecutingInternal = false {
        willSet {
            willChangeValue(forKey: "isExecuting")
        }
        didSet {
            didChangeValue(forKey: "isExecuting")
        }
    }
    
    override var isExecuting: Bool {
        return isExecutingInternal
    }
    
    fileprivate var isFinishedInternal = false {
        willSet {
            willChangeValue(forKey: "isFinished")
        }
        
        didSet {
            didChangeValue(forKey: "isFinished")
        }
    }
    
    override var isFinished: Bool {
        return isFinishedInternal
    }
    
    override func start() {
        isExecutingInternal = true
        execute()
    }
    
    func execute() {
        // TODO: Remove the async main once switching to URLSession
        Async.main {
            self.loader.completionHandler = { _, _, _ in
                self.finish()
            }
            self.loader.start()
        }
    }
    
    func finish() {
        // Notify the completion of async task and hence the completion of the operation
        
        isExecutingInternal = false
        isFinishedInternal = true
    }
}
