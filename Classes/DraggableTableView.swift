//
//  DraggableTableView.swift
//  iSub
//
//  Created by Benjamin Baron on 12/20/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit
import QuartzCore

@objc protocol View {
    // Must be a UIView or at least act like one
    var layer: CALayer { get }
    var frame: CGRect { get }
    var bounds: CGRect { get }
    var superview: UIView? { get }
    var alpha: CGFloat { get set }
}

@objc protocol DraggableCell: View {
    var containerView: UIView { get }
    var draggable: Bool { get }
    var dragItem: ISMSItem? { get }
    var indexPath: NSIndexPath? { get }
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
        
        static let locationKey            = "locationKey"
        static let dragCellKey            = "dragCellKey"
        static let dragSourceTableViewKey = "dragSourceTableViewKey"
        
        static func userInfo(location location: NSValue, dragSourceTableView: UITableView, dragCell: DraggableCell) -> [String: AnyObject] {
            var userInfo = [String: AnyObject]()
            userInfo[dragSourceTableViewKey] = dragSourceTableView
            userInfo[locationKey] = location
            userInfo[dragCellKey] = dragCell
            return userInfo
        }
    }
    
    let HorizSwipeDragMin = 3.0
    let VertSwipeDragMax = 80.0
    
    let cellEnableDelay = 1.0
    let longPressDelay = 0.33
    
    var lastDeleteToggle = NSDate()
    
    var longPressTimer: dispatch_source_t?
    var dragIndexPath: NSIndexPath?
    var dragCell: DraggableCell?
    var dragCellAlpha: CGFloat = 1.0
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
                        if let itemCell = cell as? ItemTableViewCell {
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
    
    private func imageFromCell(cell: DraggableCell) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(cell.bounds.size, cell.layer.opaque, 0.0)
        cell.layer.renderInContext(UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    private func cancelLongPress() {
        if let longPressTimer = longPressTimer {
            dispatch_source_cancel(longPressTimer)
        }
        longPressTimer = nil
    }
    
    override func touchesBegan(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.allowsSelection = false
        self.scrollEnabled = true
        dragCell = nil
        dragIndexPath = nil
        
        // Handle long press
        if let touch = touches.first {
            let point = touch.locationInView(self)
            let indexPath = self.indexPathForRowAtPoint(point)
            if let indexPath = indexPath {
                let cell = self.cellForRowAtIndexPath(indexPath)
                if let draggableCell = cell as? DraggableCell {
                    if draggableCell.draggable {
                        dragImageOffset = touch.locationInView(cell)
                        
                        let location = NSValue(CGPoint: touch.locationInView(nil))
                        let userInfo = Notifications.userInfo(location: location, dragSourceTableView: self, dragCell: draggableCell)
                        
                        //NSRunLoop.mainRunLoop().addTimer(longPressTimer!, forMode: NSRunLoopCommonModes)
                        longPressTimer = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, dispatch_get_main_queue());
                        dispatch_source_set_timer(longPressTimer!, DISPATCH_TIME_NOW, UInt64(longPressDelay * Double(NSEC_PER_SEC)), UInt64(0.25 * Double(NSEC_PER_SEC)));
                        dispatch_source_set_event_handler(longPressTimer!) {
                            self.longPressFired(userInfo)
                            print("timer fired")
                        }
                        dispatch_resume(longPressTimer!)
                    }
                }
            }
        }
        
        super.touchesBegan(touches, withEvent: event)
    }
    
    @objc private func longPressFired(userInfo: [NSObject: AnyObject]) {
        if let cell = userInfo[Notifications.dragCellKey] as? DraggableCell {
            self.scrollEnabled = false
            dragIndexPath = cell.indexPath
            dragCell = cell
            dragCellAlpha = cell.containerView.alpha
            
            let image = imageFromCell(cell)
            dragImageView = UIImageView(image: image)
            dragImageView!.frame.origin = dragImageSuperview.convertPoint(cell.frame.origin, fromView: cell.superview)
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
            
            
            UIView.animateWithDuration(0.1) {
                // Animate the cell location to be slightly off
                var origin = self.dragImageView!.frame.origin
                origin.x += 2
                origin.y -= 2
                self.dragImageView!.frame.origin = origin
                
                // Dim the cell in the table
                cell.containerView.alpha = 0.6
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
            let superviewPoint = touch.locationInView(dragImageSuperview)
            dragImageView.frame.origin = superviewPoint - dragImageOffset
            
            let windowPoint = touch.locationInView(nil)
            let userInfo = Notifications.userInfo(location: NSValue(CGPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
            NSNotificationCenter.postNotificationToMainThreadWithName(Notifications.draggingMoved, userInfo: userInfo)
        }
        
        super.touchesMoved(touches, withEvent: event)
    }

    override func touchesEnded(touches: Set<UITouch>, withEvent event: UIEvent?) {
        self.allowsSelection = true
        self.scrollEnabled = true
        
        cancelLongPress()
        
        if let touch = touches.first {
            if let dragCell = dragCell {
                let windowPoint = touch.locationInView(nil)
                let userInfo = Notifications.userInfo(location: NSValue(CGPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
                NSNotificationCenter.postNotificationToMainThreadWithName(Notifications.draggingEnded, userInfo: userInfo)
                
                dragImageView?.removeFromSuperview()
                
                UIView.animateWithDuration(0.1) {
                    // Undo the cell dimming
                    dragCell.containerView.alpha = self.dragCellAlpha
                }
            } else {
                // Select the cell if this was not a long press
                let point = touch.locationInView(self)
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
            var windowPoint = CGPointZero
            if let touch = touches?.first {
                windowPoint = touch.locationInView(nil)
            }
            
            let userInfo = Notifications.userInfo(location: NSValue(CGPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
            NSNotificationCenter.postNotificationToMainThreadWithName(Notifications.draggingCanceled, userInfo: userInfo)
            
            dragImageView?.removeFromSuperview()
        }
        
        super.touchesCancelled(touches, withEvent: event)
    }
}
