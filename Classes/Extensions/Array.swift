//
//  Array.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 9/17/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension Array {
    var second: Element? {
        let element: Element? = self.count > 0 ? self[1] : nil
        return element
    }
}
