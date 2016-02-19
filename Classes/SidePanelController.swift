//
//  SidePanelController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/5/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import JASidePanels

// KVO context pointer
// Set up non-zero-sized storage. We don't intend to mutate this variable,
// but it needs to be `var` so we can pass its address in as UnsafeMutablePointer.
//private var kvoContext = 0

class SidePanelController: JASidePanelController {

    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup KVO to hide and show the status bar when opening the side panels
        //self.addObserver(self, forKeyPath: "state", options: .New, context: &kvoContext)
        
        // TODO: Look into custom side panel animations
        //self.pushesSidePanels = true
        
        let menu = NewMenuViewController()
        self.leftPanel = menu
        self.rightPanel = PlayQueueViewController(viewModel: PlayQueueViewModel())
        menu.showDefaultViewController()
    }
    
//    override func observeValueForKeyPath(keyPath: String?, ofObject object: AnyObject?, change: [String : AnyObject]?, context: UnsafeMutablePointer<Void>) {
//        if context == &kvoContext {
//            switch self.state {
//            case JASidePanelCenterVisible:
//                UIApplication.sharedApplication().setStatusBarHidden(false, withAnimation: .Slide)
//            case JASidePanelLeftVisible, JASidePanelRightVisible:
//                UIApplication.sharedApplication().setStatusBarHidden(true, withAnimation: .Slide)
//            default:
//                break
//            }
//        } else {
//            super.observeValueForKeyPath(keyPath, ofObject: object, change: change, context: context)
//        }
//    }
//    
//    deinit {
//        self.removeObserver(self, forKeyPath: "state", context: &kvoContext)
//    }
}
