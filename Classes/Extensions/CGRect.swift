//
//  CGRect.swift
//  iSub
//
//  Created by Benjamin Baron on 1/25/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension CGRect {
    var center: CGPoint {
        return CGPoint(x: maxX - (width / 2), y: maxY - (height / 2))
    }
}
