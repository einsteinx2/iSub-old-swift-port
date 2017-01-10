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
    var indexPath: IndexPath? { get }
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
        
        static let forceTouchDetectionBegan     = "forceTouchDetectionBegan"
        static let forceTouchDetectionCanceled  = "forceTouchDetectionCanceled"
        
        static let locationKey            = "locationKey"
        static let dragCellKey            = "dragCellKey"
        static let dragSourceTableViewKey = "dragSourceTableViewKey"
        
        static func userInfo(location: NSValue, dragSourceTableView: UITableView, dragCell: DraggableCell) -> [String: AnyObject] {
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
    let longPressDelay = 150 //ms
    
    var lastDeleteToggle = Date()
    
    var longPressTimer: DispatchSourceTimer?
    var longPressStartLocation = CGPoint()
    
    var isForceTouchAvailable: Bool {
        return self.traitCollection.forceTouchCapability == .available
    }
    
    var dimDraggedCells = true
    
    fileprivate(set) var isDraggingCell: Bool = false
    fileprivate(set) var dragIndexPath: IndexPath?
    fileprivate(set) var dragCell: DraggableCell?
    fileprivate(set) var dragCellAlpha: CGFloat = 1.0
    fileprivate(set) var dragImageView: UIImageView?
    fileprivate(set) var dragImageOffset = CGPoint.zero
    var dragImageSuperview: UIView {
        get {
            // Use the top level view so we can go between controllers
            return self.window!.rootViewController!.view
        }
    }
    
    fileprivate func setup() {
        self.separatorStyle = UITableViewCellSeparatorStyle.singleLine
        self.sectionIndexBackgroundColor = UIColor.clear
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
    
    override func hitTest(_ point: CGPoint, with event: UIEvent?) -> UIView? {
        // Don't try anything when the tableview is moving and do not catch if touch is far right (potential index control)
        if !self.isDecelerating && point.x < 290 {
            
            // Find the cell
            if let indexPath = self.indexPathForRow(at: point) {
                
                if let cell = self.cellForRow(at: indexPath) {
                    
                    // TODO: Move multi delete touch handling to ItemUITableViewCell
                    
                    // Handle multi delete touching
                    if self.isEditing && point.x < 40.0 && Date().timeIntervalSince(self.lastDeleteToggle) > 0.25 {
                        self.lastDeleteToggle = Date()
                        if let itemCell = cell as? ItemTableViewCell {
                            itemCell.toggleDelete()
                        }
                    }
                }
            }
        }
        
        return super.hitTest(point, with: event)
    }
    
    override func touchesShouldCancel(in view: UIView) -> Bool {
        return true
    }
    
    override func touchesShouldBegin(_ touches: Set<UITouch>, with event: UIEvent?, in view: UIView) -> Bool {
        return true
    }
    
    // MARK: - Touch gestures for custom cell view -
    
    fileprivate func disableCellsTemporarily() {
        self.allowsSelection = false
        EX2Dispatch.runInMainThread(afterDelay: cellEnableDelay, block: {
            self.allowsSelection = true
        })
    }
    
    fileprivate func imageFromCell(_ cell: DraggableCell) -> UIImage {
        UIGraphicsBeginImageContextWithOptions(cell.bounds.size, cell.layer.isOpaque, 0.0)
        cell.layer.render(in: UIGraphicsGetCurrentContext()!)
        let image = UIGraphicsGetImageFromCurrentImageContext()
        UIGraphicsEndImageContext()
        return image!
    }
    
    fileprivate func cancelLongPress() {
        if let longPressTimer = longPressTimer {
            longPressTimer.cancel()
            self.longPressTimer = nil
        }
    }
    
    override func touchesBegan(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.allowsSelection = false
        self.isScrollEnabled = true
        dragCell = nil
        dragIndexPath = nil
        isDraggingCell = false
        
        // Handle long press / force touch
        if let touch = touches.first {
            let point = touch.location(in: self)
            longPressStartLocation = point
            
            if let indexPath = self.indexPathForRow(at: point) {
                let cell = self.cellForRow(at: indexPath)
                if let draggableCell = cell as? DraggableCell {
                    if draggableCell.draggable {
                        dragImageOffset = touch.location(in: cell)
                        
                        let location = NSValue(cgPoint: touch.location(in: nil))
                        let userInfo = Notifications.userInfo(location: location, dragSourceTableView: self, dragCell: draggableCell)
                        
                        if isForceTouchAvailable {
                            if touch.force >= minimumForce {
                                forceTouchStarted(touch: touch)
                            }
                        } else {
                            longPressTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                            longPressTimer!.scheduleOneshot(deadline: .now() + .milliseconds(longPressDelay), leeway: .nanoseconds(0))
                            longPressTimer!.setEventHandler {
                                self.longPressFired(userInfo)
                            }
                            longPressTimer!.resume()
                        }
                    }
                }
            }
        }
        
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Cancel the tap and hold if user moves finger too far
        if let touch = touches.first {
            let point = touch.location(in: self)
            let distance = hypot(longPressStartLocation.x - point.x, longPressStartLocation.y - point.y)
            if distance > 5.0 {
                if isForceTouchActive {
                    let point = touch.location(in: self)
                    if let indexPath = self.indexPathForRow(at: point), let draggableCell = self.cellForRow(at: indexPath) as? DraggableCell {
                        draggableCell.containerView.alpha = self.dragCellAlpha
                    }
                    
                    isForceTouchActive = false
                    dragImageView?.removeFromSuperview()
                    dragImageView = nil
                }
                
                cancelLongPress()
            } else if isForceTouchActive {
                forceTouchForceChanged(touch: touch)
            } else if !isDraggingCell && isForceTouchAvailable && touch.force >= minimumForce {
                forceTouchStarted(touch: touch)
            }
        }
        
        if isDraggingCell, let dragImageView = dragImageView, let dragCell = dragCell, let touch = touches.first {
            let superviewPoint = touch.location(in: dragImageSuperview)
            dragImageView.frame.origin = superviewPoint - dragImageOffset
            
            let windowPoint = touch.location(in: nil)
            let userInfo = Notifications.userInfo(location: NSValue(cgPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
            NotificationCenter.postNotificationToMainThread(withName: Notifications.draggingMoved, userInfo: userInfo)
        }
        
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        self.allowsSelection = true
        self.isScrollEnabled = true
        isDraggingCell = false
        
        dragImageView?.removeFromSuperview()
        dragImageView = nil
        cancelLongPress()
        
        if let touch = touches.first {
            if let dragCell = dragCell {
                if dimDraggedCells {
                    if isForceTouchActive {
                        dragCell.containerView.alpha = self.dragCellAlpha
                    } else {
                        UIView.animate(withDuration: 0.1) {
                            // Undo the cell dimming
                            dragCell.containerView.alpha = self.dragCellAlpha
                        }
                    }
                }
                
                let windowPoint = touch.location(in: nil)
                let userInfo = Notifications.userInfo(location: NSValue(cgPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
                NotificationCenter.postNotificationToMainThread(withName: Notifications.draggingEnded, userInfo: userInfo)
            } else {
                // Select the cell if this was not a long press
                let point = touch.location(in: self)
                if (self.isEditing && Float(point.x) > 40.0) || !self.isEditing {
                    let indexPath: IndexPath? = self.indexPathForRow(at: point)
                    
                    if indexPath != nil {
                        self.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                        if let delegate: UITableViewDelegate = self.delegate {
                            delegate.tableView?(self, didSelectRowAt: indexPath!)
                        }
                    }
                }
            }
        }
        
        isForceTouchActive = false
        
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        self.allowsSelection = true
        self.isScrollEnabled = true
        isDraggingCell = false
        
        dragImageView?.removeFromSuperview()
        dragImageView = nil
        cancelLongPress()
        
        if let dragCell = dragCell {
            if dimDraggedCells {
                if isForceTouchActive {
                    dragCell.containerView.alpha = self.dragCellAlpha
                } else {
                    UIView.animate(withDuration: 0.1) {
                        // Undo the cell dimming
                        dragCell.containerView.alpha = self.dragCellAlpha
                    }
                }
            }
            
            var windowPoint = CGPoint.zero
            if let touch = touches?.first {
                windowPoint = touch.location(in: nil)
            }
            
            let userInfo = Notifications.userInfo(location: NSValue(cgPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
            NotificationCenter.postNotificationToMainThread(withName: Notifications.draggingCanceled, userInfo: userInfo)
        }
        
        isForceTouchActive = false
        
        super.touchesCancelled(touches!, with: event)
    }
    
    @objc fileprivate func longPressFired(_ userInfo: [AnyHashable: Any]) {
        if let cell = userInfo[Notifications.dragCellKey] as? DraggableCell {
            self.isScrollEnabled = false
            isDraggingCell = true
            dragIndexPath = cell.indexPath
            dragCell = cell
            if dimDraggedCells {
                dragCellAlpha = cell.containerView.alpha
            }
            
            let image = imageFromCell(cell)
            dragImageView = UIImageView(image: image)
            dragImageView!.frame.origin = dragImageSuperview.convert(cell.frame.origin, from: cell.superview)
            dragImageView!.layer.shadowRadius = 6.0
            dragImageView!.layer.shadowOpacity = 0.0
            dragImageView!.layer.shadowOffset = CGSize(width: 0, height: 2)
            self.window!.rootViewController!.view.addSubview(dragImageView!)
            
            // Animate the shadow opacity so it gives the effect of the cell lifting upwards
            let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
            shadowAnimation.fromValue = 0.0
            shadowAnimation.toValue = 0.3
            shadowAnimation.duration = 0.1
            dragImageView!.layer.add(shadowAnimation, forKey: "shadowOpacity")
            dragImageView!.layer.shadowOpacity = 0.3
            
            
            UIView.animate(withDuration: 0.1, animations: {
                // Animate the cell location to be slightly off
                var origin = self.dragImageView!.frame.origin
                origin.x += 3
                origin.y -= 3
                self.dragImageView!.frame.origin = origin
                
                // Dim the cell in the table
                if self.dimDraggedCells {
                    cell.containerView.alpha = 0.6
                }
            })
            
            // Match the animation so movement is smooth
            dragImageOffset.x -= 3
            dragImageOffset.y += 3
            
            // Taptic feedback
            tapticFeedback()
            
            NotificationCenter.postNotificationToMainThread(withName: Notifications.draggingBegan, userInfo: userInfo)
        }
    }
    
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        cancelLongPress()
        super.setContentOffset(contentOffset, animated: animated)
    }
    
    fileprivate let minimumForce: CGFloat = 3.0
    fileprivate let activationForce: CGFloat = 6.0
    fileprivate let maxDragImageOffset: CGFloat = 5.0
    fileprivate var isForceTouchActive = false
    
    fileprivate func calculateDragImageOffset(force: CGFloat) -> CGFloat {
        return convertToRange(number: force, inputMin: minimumForce, inputMax: activationForce, outputMin: 0, outputMax: maxDragImageOffset)
    }
    
    fileprivate func originalDragImageOffset(draggableCell: DraggableCell) -> CGPoint {
        return dragImageSuperview.convert(draggableCell.frame.origin, from: draggableCell.superview)
    }
    
    fileprivate func forceTouchStarted(touch: UITouch) {
        let point = touch.location(in: self)
        if let indexPath = self.indexPathForRow(at: point) {
            let cell = self.cellForRow(at: indexPath)
            if let draggableCell = cell as? DraggableCell {
                if draggableCell.draggable {
                    isForceTouchActive = true
                    self.isScrollEnabled = false
                    dragIndexPath = draggableCell.indexPath
                    dragCell = draggableCell
                    if dimDraggedCells {
                        dragCellAlpha = draggableCell.containerView.alpha
                    }
                    
                    let image = imageFromCell(draggableCell)
                    dragImageView = UIImageView(image: image)
                    dragImageView?.frame.origin = originalDragImageOffset(draggableCell: draggableCell)
                    dragImageView?.layer.shadowRadius = 6.0
                    dragImageView?.layer.shadowOpacity = 0.0
                    dragImageView?.layer.shadowOffset = CGSize(width: 0, height: 2)
                    self.window!.rootViewController!.view.addSubview(dragImageView!)
                    
                    // Animate the shadow opacity so it gives the effect of the cell lifting upwards
                    let shadowAnimation = CABasicAnimation(keyPath: "shadowOpacity")
                    shadowAnimation.fromValue = 0.0
                    shadowAnimation.toValue = 0.3
                    shadowAnimation.duration = 0.1
                    dragImageView?.layer.add(shadowAnimation, forKey: "shadowOpacity")
                    dragImageView?.layer.shadowOpacity = 0.3
                    
                    let offset = calculateDragImageOffset(force: touch.force)
                    UIView.animate(withDuration: 0.1, animations: {
                        // Animate the cell location to be slightly off
                        var origin = self.originalDragImageOffset(draggableCell: draggableCell)
                        origin.x += offset
                        origin.y -= offset
                        self.dragImageView?.frame.origin = origin
                        
                        // Dim the cell in the table
                        if self.dimDraggedCells {
                            draggableCell.containerView.alpha = 0.6
                        }
                    })
                    
                    NotificationCenter.postNotificationToMainThread(withName: Notifications.forceTouchDetectionBegan)
                }
            }
        }
    }
    
    fileprivate func forceTouchForceChanged(touch: UITouch) {
        if isForceTouchActive {
            var force = touch.force
            if force > activationForce {
                force = activationForce
            } else if force < minimumForce {
                force = minimumForce
            }
            
            var offset = calculateDragImageOffset(force: force)
            if force >= activationForce {
                tapticFeedback(heavy: false)
                
                offset = maxDragImageOffset
                dragImageOffset.x -= offset
                dragImageOffset.y += offset
                
                isDraggingCell = true
                isForceTouchActive = false
                
                let location = NSValue(cgPoint: touch.location(in: nil))
                let userInfo = Notifications.userInfo(location: location, dragSourceTableView: self, dragCell: dragCell!)
                NotificationCenter.postNotificationToMainThread(withName: Notifications.draggingBegan, userInfo: userInfo)
            }
            
            UIView.animate(withDuration: 0.1, delay: 0.0, options: .beginFromCurrentState, animations: { 
                // Animate the cell location to be slightly off
                var origin = self.originalDragImageOffset(draggableCell: self.dragCell!)
                origin.x += offset
                origin.y -= offset
                self.dragImageView?.frame.origin = origin
            }, completion: nil)
        }
    }
}
