//
//  UITraitEnvironment.swift
//  iSub
//
//  Created by Benjamin Baron on 1/9/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension UITraitEnvironment {
    var isForceTouchAvailable: Bool {
        return self.traitCollection.forceTouchCapability == .available
    }
}
