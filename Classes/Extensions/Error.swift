//
//  Error.swift
//  iSub
//
//  Created by Benjamin Baron on 1/15/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Error {
    var domain: String {
        return (self as NSError).domain
    }
    
    var code: Int {
        return (self as NSError).code
    }
    
    var localizedDescription: String {
        return (self as NSError).localizedDescription
    }
}
