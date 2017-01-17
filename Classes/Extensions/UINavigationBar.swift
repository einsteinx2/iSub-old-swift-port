//
//  UINavigationBar.swift
//  iSub
//
//  Created by Benjamin Baron on 1/16/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate struct AssociatedKeys {
    static var fixedNavigationBarSize = "sizeThatFits_fixedNavigationBarSize"
}

extension UINavigationBar {
    /**
     * If set to YES, UINavigationBar height will not change after status bar was hidden.
     * Normally on iOS 7+ navigation bar height equals to 64 px, when status bar is shown.
     * After it is hidden, its height is changed to 44 px by default.
     */
    var fixedHeightWhenStatusBarHidden: Bool {
        get {
            return objc_getAssociatedObject(self, &AssociatedKeys.fixedNavigationBarSize) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &AssociatedKeys.fixedNavigationBarSize, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    func sizeThatFits_FixedHeightWhenStatusBarHidden(_ size: CGSize) -> CGSize {
        if UIApplication.shared.isStatusBarHidden && fixedHeightWhenStatusBarHidden {
            return CGSize(width: self.frame.size.width, height: 64)
        }
        return sizeThatFits_FixedHeightWhenStatusBarHidden(size)
    }
    
    override open class func initialize() {
        if self === UINavigationBar.self {
            let originalMethod = class_getInstanceMethod(self, #selector(UINavigationBar.sizeThatFits(_:)))
            let newMethod = class_getInstanceMethod(self, #selector(UINavigationBar.sizeThatFits_FixedHeightWhenStatusBarHidden(_:)))
            method_exchangeImplementations(originalMethod, newMethod)
        }
    }
}
