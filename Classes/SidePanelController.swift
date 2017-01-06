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
    
    // MARK: - Status Bar -
    
    override var preferredStatusBarStyle: UIStatusBarStyle {
        return .lightContent
    }
    
    override var prefersStatusBarHidden: Bool {
        return hideStatusBar
    }
    
    fileprivate var hideStatusBar: Bool = false {
        didSet {
            UIView.animate(withDuration: 0.2) {
                self.setNeedsStatusBarAppearanceUpdate()
            }
        }
    }
    
    // MARK: - Lifecycle -
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Setup KVO to hide and show the status bar when opening the side panels
        self.addObserver(self, forKeyPath: "state", options: .new, context: &kvoContext)
        
        // TODO: Look into custom side panel animations
        self.pushesSidePanels = true
        self.bounceOnSidePanelOpen = false
        
        self.panningLimitedToTopViewController = false
        self.panningRightLimitedToTopViewController = false
        self.panningLeftLimitedToTopViewController = true
        
        self.shouldResizeLeftPanel = true
        self.shouldResizeRightPanel = true
        
        let menu = NewMenuViewController()
        self.leftPanel = menu
        self.rightPanel = PlayQueueViewController(viewModel: PlayQueueViewModel())
        menu.showDefaultViewController()
        
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(draggingBegan(_:)), name: DraggableTableView.Notifications.draggingBegan, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(draggingMoved(_:)), name: DraggableTableView.Notifications.draggingMoved, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(draggingEnded(_:)), name: DraggableTableView.Notifications.draggingEnded, object: nil)
        NotificationCenter.addObserver(onMainThread: self, selector: #selector(draggingCanceled(_:)), name: DraggableTableView.Notifications.draggingCanceled, object: nil)
    }
    
    deinit {
        self.removeObserver(self, forKeyPath: "state", context: &kvoContext)
    }
    
    // MARK: - Side Panels -
    
    override func stylePanel(_ panel: UIView!) {
        // Intentionally empty to prevent rounded corners on panels
    }
    
    override func gestureRecognizerShouldBegin(_ gestureRecognizer: UIGestureRecognizer) -> Bool {
        let shouldBegin = super.gestureRecognizerShouldBegin(gestureRecognizer)
        if shouldBegin {
            hideStatusBar = true
        }
        return shouldBegin
    }
    
    override func observeValue(forKeyPath keyPath: String?, of object: Any?, change: [NSKeyValueChangeKey : Any]?, context: UnsafeMutableRawPointer?) {
        if context == &kvoContext {
            switch state {
            case JASidePanelCenterVisible:
                hideStatusBar = false
            case JASidePanelLeftVisible, JASidePanelRightVisible:
                hideStatusBar = true
            default:
                break
            }
        } else {
            super.observeValue(forKeyPath: keyPath, of: object, change: change, context: context)
        }
    }
    
    // MARK: - Draggable TableView -
    
    @objc fileprivate func draggingBegan(_ notification: Notification) {
        allowLeftSwipe = false
        allowRightSwipe = false
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
        
        allowLeftSwipe = true
        allowRightSwipe = true
    }
    
    @objc fileprivate func draggingCanceled(_ notification: Notification) {
        if state == JASidePanelRightVisible {
            showCenterPanel(animated: true)
        }
        
        allowLeftSwipe = true
        allowRightSwipe = true
    }
}
