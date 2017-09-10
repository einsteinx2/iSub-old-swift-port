//
//  SyncFunc.swift
//  KSHLSPlayer
//
//  Created by Ken Sun on 2016/1/18.
//  Copyright © 2016年 KS. All rights reserved.
//

import Foundation

func synced(lock: AnyObject, closure: () -> ()) {
    objc_sync_enter(lock)
    closure()
    objc_sync_exit(lock)
}

func synced<T>(lock: AnyObject, closure: () -> T) -> T {
    objc_sync_enter(lock)
    let v = closure()
    objc_sync_exit(lock)
    return v
}