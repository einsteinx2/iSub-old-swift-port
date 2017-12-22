//
//  UIViewController.swift
//  iSub Beta
//
//  Created by Andres Felipe Rodriguez Bolivar on 12/21/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

extension UIViewController {
    
    static var top: UIViewController? {
        return topViewController()
    }
    
    static var root: UIViewController? {
        return UIApplication.shared.delegate?.window??.rootViewController
    }
    
    static func topViewController(from viewController: UIViewController? = UIViewController.root) -> UIViewController? {
        if let tabBarViewController = viewController as? UITabBarController {
            return topViewController(from: tabBarViewController.selectedViewController)
        } else if let navigationController = viewController as? UINavigationController {
            return topViewController(from: navigationController.visibleViewController)
        } else if let presentedViewController = viewController?.presentedViewController {
            return topViewController(from: presentedViewController)
        } else {
            return viewController
        }
    }
}
