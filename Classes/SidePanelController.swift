//
//  SidePanelController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/5/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit
import JASidePanels
import libSub

// KVO context pointer
// Set up non-zero-sized storage. We don't intend to mutate this variable,
// but it needs to be `var` so we can pass its address in as UnsafeMutablePointer.
//private var kvoContext = 0

class SidePanelController: JASidePanelController {
        
    override func preferredStatusBarStyle() -> UIStatusBarStyle {
        return .LightContent
    }
    
    override func stylePanel(panel: UIView!) {
        // Intentionally empty to prevent rounded corners on panels
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup KVO to hide and show the status bar when opening the side panels
        //self.addObserver(self, forKeyPath: "state", options: .New, context: &kvoContext)
        
        // TODO: Look into custom side panel animations
        //self.pushesSidePanels = true
        
        self.panningLimitedToTopViewController = false
        
        self.shouldResizeLeftPanel = true
        self.shouldResizeRightPanel = true
        
        let menu = NewMenuViewController()
        self.leftPanel = menu
        self.rightPanel = PlayQueueViewController(viewModel: PlayQueueViewModel())
        menu.showDefaultViewController()
        
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(SidePanelController.draggingBegan(_:)), name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(SidePanelController.draggingMoved(_:)), name: DraggableTableView.Notifications.draggingMoved, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(SidePanelController.draggingEnded(_:)), name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NSNotificationCenter.addObserverOnMainThread(self, selector: #selector(SidePanelController.draggingCanceled(_:)), name: DraggableTableView.Notifications.draggingCanceled, object: nil)
    }
    
    @objc private func draggingBegan(notification: NSNotification) {
        self.allowLeftSwipe = false
        self.allowRightSwipe = false
    }
    
    @objc private func draggingMoved(notification: NSNotification) {
        if let location = notification.userInfo?[DraggableTableView.Notifications.locationKey] as? NSValue {
            let point = location.CGPointValue()
            
            if point.x > self.view.frame.width - 100 && self.state != JASidePanelRightVisible {
                self.showRightPanelAnimated(true)
            } else if point.x < 80 && self.state == JASidePanelRightVisible {
                self.showCenterPanelAnimated(true)
            }
        }
    }
    
    @objc private func draggingEnded(notification: NSNotification) {
        if self.state == JASidePanelRightVisible {
            EX2Dispatch.runInMainThreadAfterDelay(0.3) {
                //self.showCenterPanelAnimated(true)
            }
        }
        
        self.allowLeftSwipe = true
        self.allowRightSwipe = true
    }
    
    @objc private func draggingCanceled(notification: NSNotification) {
        if self.state == JASidePanelRightVisible {
            self.showCenterPanelAnimated(true)
        }
        
        self.allowLeftSwipe = true
        self.allowRightSwipe = true
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
