//
//  LoadingScreen.swift
//  iSub Beta
//
//  Created by Benjamin Baron on 7/2/17.
//  Copyright © 2017 Ben Baron. All rights reserved.
//

import Foundation

fileprivate var alert: UIAlertController?

struct LoadingScreen {
    static func show(withMessage message: String? = nil) {
        DispatchQueue.main.async {
            alert?.dismiss(animated: true, completion: nil)
            
            alert = UIAlertController(title: nil, message: message, preferredStyle: .alert)
            
            let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
            loadingIndicator.hidesWhenStopped = true
            loadingIndicator.activityIndicatorViewStyle = UIActivityIndicatorViewStyle.gray
            loadingIndicator.startAnimating();
            
            alert!.view.addSubview(loadingIndicator)
            AppDelegate.si.sidePanelController.present(alert!, animated: true, completion: nil)
        }
    }
    
    static func hide() {
        DispatchQueue.main.async {
            if let alert = alert {
                alert.dismiss(animated: true, completion: nil)
            }
            alert = nil
        }
    }
}
