//
//  DraggableTableView.swift
//  iSub
//
//  Created by Benjamin Baron on 12/20/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import libSub
import Foundation
import UIKit
import QuartzCore

@objc protocol DraggableCell {
    var draggable: Bool { get }
    var dragItem: ISMSItem? { get }
}

private func +(left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

private func -(left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

class DraggableTableView: UITableView {
    
    struct Notifications {
        static let draggingBegan    = "draggingBegan"
        static let draggingMoved    = "draggingMoved"
        static let draggingEnded    = "draggingEnded"
        static let draggingCanceled = "draggingCanceled"
        
        static let locationKey = "locationKey"
        static let itemKey     = "itemKey"
        
        static func userInfo(location location: NSValue, item: ISMSItem?) -> [String: AnyObject] {
            var userInfo = [String: AnyObject]()
            userInfo[locationKey] = location
            if let item = item {
                userInfo[itemKey] = item
            }
            return userInfo
        }
    }
    
    let HorizSwipeDragMin = 3.0
    let VertSwipeDragMax = 80.0
    
    let cellEnableDelay = 1.0
    let longPressDelay = 0.25
    
    var lastDeleteToggle = NSDate()
    
    var longPressTimer: NSTimer?
    var dragCell: DraggableCell?
    var dragImageView: UIImageView?
    var dragImageOffset = CGPointZero
    var dragImageSuperview: UIView {
        get {
            // Use the top level view so we can go between controllers
            return self.window!.rootViewController!.view
        }
    }
    
    private func setup() {
        self.separatorStyle = UITableViewCellSeparatorStyle.SingleLine
        self.sectionIndexBackgroundColor = UIColor.clearColor()
    }
    
    override init(frame: CGRect, style: UITableViewStyle) {
        super.init(frame: frame, style: style)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    // MARK: - Touch Gestures Interception -
    
    override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        // Don't try anything when the tableview is moving and do not catch if touch is far right (potential index control)
        if !self.decelerating && point.x < 290 {
            
            // Find the cell
            if let indexPath = self.indexPathForRowAtPoint(point) {
                
                if let cell = self.cellForRowAtIndexPath(indexPath) {
                    
                    // TODO: Move multi delete touch handling to ItemUITableViewCell
                    
                    // Handle multi delete touching
                    if self.editing && point.x < 40.0 && NSDate().timeIntervalSinceDate(self.lastDeleteToggle) > 0.25 {
                        self.lastDeleteToggle = NSDate()
                        if let itemCell = cell as? NewItemTableViewCell {
                            itemCell.toggleDelete()
                        }
                    }
                }
            }
        }
        
        return super.hitTest(point, withEvent: event)
    }
    
    override func touchesShouldCancelInContentView(view: UIView) -> Bool {
        return true
    }
    
    override func touchesShouldBegin(touches: Set<UITouch>, withEvent event: UIEvent?, inContentView view: UIView) -> Bool {
        return true
    }
    
    // MARK: - Touch gestures for custom cell view -
    
    private func disableCellsTemporarily() {
        self.allowsSelection = false
        EX2Dispatch.runInMainThreadAfterDelay(cellEnableDelay, block: {
            self.allowsSelection = true
        })
    }
    
    private func imageFromView(view: UIView) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(view.bounds.size, view.opaque, 0.0)
        view.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image
    }
    
    private func cancelLongPress() {
        longPressTimer?.invalidate();
        longPressTimer = nil
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.allowsSelection = false
        self.scrollEnabled = true
    
        // Handle long press
        if let touch = touches.first {
            let point = touch.locationInView(self)
            let indexPath = self.indexPathForRowAtPoint(point)
            if let indexPath = indexPath {
                let cell = self.cellForRowAtIndexPath(indexPath)
                if let draggableView = cell as? DraggableCell {
                    if draggableView.draggable {
                        dragCell = draggableView
                        dragImageOffset = touch.locationInView(cell)
                        
                        var userInfo = [String: AnyObject]()
                        let location = touch.locationInView(dragImageSuperview)
                        userInfo[Notifications.locationKey] = NSValue(CGPoint: location)
                        if let dragItem = draggableView.dragItem {
                            userInfo[Notifications.itemKey] = dragItem
                        }
                        
                        longPressTimer = NSTimer.scheduledTimerWithTimeInterval(longPressDelay, target: self, selector: #selector(DraggableTableView.longPressFired(_:)), userInfo: userInfo, repeats: false);
                    }
                }
            }
        }
        
        super.touchesBegan(touches, withEvent: event)
    }
    
    @objc private func longPressFired(notification: NSNotification) {
        if let dragCell = dragCell as? UITableViewCell, userInfo = notification.userInfo {
            self.scrollEnabled = false
            
            let image = imageFromView(dragCell)
            dragImageView = UIImageView(image: image)
            dragImageView!.frame.origin = dragImageSuperview.convertPoint(dragCell.frame.origin, fromView: dragCell.superview)
            dragImageView!.layer.shadowRadius = 6.0
            dragImageView!.layer.shadowOpacity = 0.0
            dragImageView!.layer.shadowOffset = CGSize(width: 0, height: 2)
            self.window!.rootViewController!.view.addSubview(dragImageView!)
            
            // Animate the shadow opacity so it gives the effect of the cell lifting upwards
            let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            shadowAnimation.fromValue = 0.0
            shadowAnimation.toValue = 0.3
            shadowAnimation.duration = 0.1
            dragImageView!.layer.addAnimation(shadowAnimation, forKey: "shadowOpacity")
            dragImageView!.layer.shadowOpacity = 0.3
            
            // Animate the cell location to be slightly off
            UIView.animateWithDuration(0.1) {
                var origin = self.dragImageView!.frame.origin
                origin.x += 2
                origin.y -= 2
                self.dragImageView!.frame.origin = origin
            }
            
            // Match the animation so movement is smooth
            dragImageOffset.x -= 2
            dragImageOffset.y += 2
            
            NSNotificationCenter.postNotificationToMainThreadWithName(Notifications.draggingBegan, userInfo: userInfo)
        }
    }
    
    override func touchesMoved(touches: Set<UITouch>, withEvent event: UIEvent?) {
        // Cancel the tap and hold if user moves finger
        cancelLongPress()
        
        if let dragImageView = dragImageView, dragCell = dragCell, touch = touches.first {
            let point = touch.locationInView(dragImageSuperview)
            dragImageView.frame.origin = point - dragImageOffset
            
            let userInfo = Notifications.userInfo(location: NSValue(CGPoint: point), item: dragCell.dragItem)
            NSNotificationCenter.postNotificationToMainThreadWithName(Notifications.draggingMoved, userInfo: userInfo)
        }
        
        super.touchesMoved(touches, withEvent: event)
    }

    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.allowsSelection = true
        self.scrollEnabled = true
        
        cancelLongPress()
        
        if let touch = touches.first {
            let point = touch.locationInView(dragImageSuperview)
            
            if let dragCell = dragCell {
                let userInfo = Notifications.userInfo(location: NSValue(CGPoint: point - dragImageOffset), item: dragCell.dragItem)
                NSNotificationCenter.postNotificationToMainThreadWithName(Notifications.draggingEnded, userInfo: userInfo)
                
                dragImageView?.removeFromSuperview()
            } else {
                // Select the cell if this was a touch not a swipe or tap and hold
                if (self.editing && Float(point.x) > 40.0) || !self.editing {
                    let indexPath: NSIndexPath? = self.indexPathForRowAtPoint(point)
                    
                    if indexPath != nil {
                        self.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: .None)
                        if let delegate: UITableViewDelegate = self.delegate {
                            delegate.tableView?(self, didSelectRowAtIndexPath: indexPath!)
                        }
                    }
                }
            }
        }
        
        super.touchesEnded(touches, withEvent: event)
    }
    
    override func touchesCancelled(touches: Set<UITouch>?, withEvent event: UIEvent?) {
        self.allowsSelection = true
        self.scrollEnabled = true
        
        cancelLongPress()
        
        if let dragCell = dragCell {
            var point = CGPointZero
            if let touch = touches?.first {
                point = touch.locationInView(dragImageSuperview) - dragImageOffset
            }
            
            let userInfo = Notifications.userInfo(location: NSValue(CGPoint: point), item: dragCell.dragItem)
            NSNotificationCenter.postNotificationToMainThreadWithName(Notifications.draggingCanceled, userInfo: userInfo)
            
            dragImageView?.removeFromSuperview()
        }
        
        super.touchesCancelled(touches, withEvent: event)
    }
}
