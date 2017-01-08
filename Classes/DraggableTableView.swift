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
    var dragIndexPath: IndexPath?
    var dragCell: DraggableCell?
    var dragCellAlpha: CGFloat = 1.0
    var dragImageView: UIImageView?
    var dragImageOffset = CGPoint.zero
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
        
        // Handle long press
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
                        
                        longPressTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
                        longPressTimer!.scheduleOneshot(deadline: .now() + .milliseconds(longPressDelay), leeway: .nanoseconds(0))
                        longPressTimer!.setEventHandler {
                            self.longPressFired(userInfo)
                            print("timer fired")
                        }
                        longPressTimer!.resume()
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
                cancelLongPress()
            }
        }
        
        if let dragImageView = dragImageView, let dragCell = dragCell, let touch = touches.first {
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
        
        cancelLongPress()
        
        if let touch = touches.first {
            if let dragCell = dragCell {
                let windowPoint = touch.location(in: nil)
                let userInfo = Notifications.userInfo(location: NSValue(cgPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
                NotificationCenter.postNotificationToMainThread(withName: Notifications.draggingEnded, userInfo: userInfo)
                
                dragImageView?.removeFromSuperview()
                
                UIView.animate(withDuration: 0.1, animations: {
                    // Undo the cell dimming
                    dragCell.containerView.alpha = self.dragCellAlpha
                }) 
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
        
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        self.allowsSelection = true
        self.isScrollEnabled = true
        
        cancelLongPress()
        
        if let dragCell = dragCell {
            var windowPoint = CGPoint.zero
            if let touch = touches?.first {
                windowPoint = touch.location(in: nil)
            }
            
            let userInfo = Notifications.userInfo(location: NSValue(cgPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
            NotificationCenter.postNotificationToMainThread(withName: Notifications.draggingCanceled, userInfo: userInfo)
            
            dragImageView?.removeFromSuperview()
        }
        
        super.touchesCancelled(touches!, with: event)
    }
    
    @objc fileprivate func longPressFired(_ userInfo: [AnyHashable: Any]) {
        if let cell = userInfo[Notifications.dragCellKey] as? DraggableCell {
            self.isScrollEnabled = false
            dragIndexPath = cell.indexPath
            dragCell = cell
            dragCellAlpha = cell.containerView.alpha
            
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
                origin.x += 2
                origin.y -= 2
                self.dragImageView!.frame.origin = origin
                
                // Dim the cell in the table
                cell.containerView.alpha = 0.6
            })
            
            // Match the animation so movement is smooth
            dragImageOffset.x -= 2
            dragImageOffset.y += 2
            
            NotificationCenter.postNotificationToMainThread(withName: Notifications.draggingBegan, userInfo: userInfo)
        }
    }
    
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        cancelLongPress()
        super.setContentOffset(contentOffset, animated: animated)
    }
}
