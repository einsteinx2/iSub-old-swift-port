//
//  SidePanelController.swift
//  iSub
//
//  Created by Benjamin Baron on 2/5/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

// KVO context pointer
// Set up non-zero-sized storage. We don't intend to mutate this variable,
// but it needs to be `var` so we can pass its address in as UnsafeMutablePointer.
private var kvoContext = 0

class SidePanelController: JASidePanelController {
        
//    override func preferredStatusBarStyle() -> UIStatusBarStyle {
//        return .lightContent
//    }
    
    override func stylePanel(_ panel: UIView!) {
        // Intentionally empty to prevent rounded corners on panels
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup KVO to hide and show the status bar when opening the side panels
        self.addObserver(self, forKeyPath: "state", options: .new, context: &kvoContext)
        
        // TODO: Look into custom side panel animations
        //self.pushesSidePanels = true
        
        self.panningLimitedToTopViewController = false
        
        self.shouldResizeLeftPanel = true
        self.shouldResizeRightPanel = true
        
        let menu = NewMenuViewController()
        self.leftPanel = menu
        self.rightPanel = PlayQueueViewController(viewModel: PlayQueueViewModel())
        menu.showDefaultViewController()
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(SidePanelController.draggingBegan(_:)), name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(SidePanelController.draggingMoved(_:)), name: DraggableTableView.Notifications.draggingMoved, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(SidePanelController.draggingEnded(_:)), name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(SidePanelController.draggingCanceled(_:)), name: DraggableTableView.Notifications.draggingCanceled, object: nil)
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: "state", context: &kvoContext)
    }
    
    @objc fileprivate func draggingBegan(_ notification: Notification) {
        self.allowLeftSwipe = false
        self.allowRightSwipe = false
    }
    
    @objc fileprivate func draggingMoved(_ notification: Notification) {
        if let location = notification.userInfo?[DraggableTableView.Notifications.locationKey] as? NSValue {
            let point = location.cgPointValue
            
            if point.x > self.view.frame.width - 50 && self.state != JASidePanelRightVisible {
                self.showRightPanel(animated: true)
            } else if point.x < 50 && self.state == JASidePanelRightVisible {
                self.showCenterPanel(animated: true)
            }
        }
    }
    
    @objc fileprivate func draggingEnded(_ notification: Notification) {
        if self.state == JASidePanelRightVisible {
            EX2Dispatch.runInMainThread(afterDelay: 0.3) {
                //self.showCenterPanelAnimated(true)
            }
        }
        
        self.allowLeftSwipe = true
        self.allowRightSwipe = true
    }
    
    @objc fileprivate func draggingCanceled(_ notification: Notification) {
        if self.state == JASidePanelRightVisible {
            self.showCenterPanel(animated: true)
        }
        
        self.allowLeftSwipe = true
        self.allowRightSwipe = true
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            switch self.state {
            case JASidePanelCenterVisible:
                UIApplication.shared.setStatusBarHidden(false, with: .none)
            case JASidePanelLeftVisible, JASidePanelRightVisible:
                UIApplication.shared.setStatusBarHidden(true, with: .none)
            default:
                break
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
}
