//
//  Swizzling.swift
//  iSub
//
//  Created by Benjamin Baron on 4/5/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate func swizzling(forClass: AnyClass, originalSelector: Selector, swizzledSelector: Selector) {
    let originalMethod = class_getInstanceMethod(forClass, originalSelector)
    let swizzledMethod = class_getInstanceMethod(forClass, swizzledSelector)
    method_exchangeImplementations(originalMethod, swizzledMethod)
}

fileprivate var hasSwizzled = false
func swizzleMethods() {
    if !hasSwizzled {
        hasSwizzled = true
        
        UINavigationBar.swizzle()
    }
}

import Foundation

fileprivate struct UINavigationBarAssociatedKeys {
    static var fixedNavigationBarSize = "sizeThatFits_fixedNavigationBarSize"
}

extension UINavigationBar {
    fileprivate static let fixedNavigationBarSize = "sizeThatFits_fixedNavigationBarSize"
    
    /**
     * If set to YES, UINavigationBar height will not change after status bar was hidden.
     * Normally on iOS 7+ navigation bar height equals to 64 px, when status bar is shown.
     * After it is hidden, its height is changed to 44 px by default.
     */
    var fixedHeightWhenStatusBarHidden: Bool {
        get {
            return objc_getAssociatedObject(self, &UINavigationBarAssociatedKeys.fixedNavigationBarSize) as? Bool ?? false
        }
        set {
            objc_setAssociatedObject(self, &UINavigationBarAssociatedKeys.fixedNavigationBarSize, newValue, .OBJC_ASSOCIATION_RETAIN)
        }
    }
    
    fileprivate class func swizzle() {
        let originalSelector = #selector(sizeThatFits(_:))
        let swizzledSelector = #selector(sizeThatFits_FixedHeightWhenStatusBarHidden(_:))
        swizzling(forClass: self, originalSelector: originalSelector, swizzledSelector: swizzledSelector)
    }
    
    @objc fileprivate func sizeThatFits_FixedHeightWhenStatusBarHidden(_ size: CGSize) -> CGSize {
        if UIApplication.shared.isStatusBarHidden && fixedHeightWhenStatusBarHidden {
            return CGSize(width: self.frame.size.width, height: 64)
        }
        return sizeThatFits_FixedHeightWhenStatusBarHidden(size)
    }
}
