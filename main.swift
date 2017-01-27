//
//  main.swift
//  iSub
//
//  Created by Benjamin Baron on 1/26/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

CommandLine.unsafeArgv.withMemoryRebound(to: UnsafeMutablePointer<Int8>.self, capacity: Int(CommandLine.argc)) { argv in
    _ = UIApplicationMain(CommandLine.argc, argv, NSStringFromClass(Application.self), NSStringFromClass(AppDelegate.self))
}
