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

protocol View {
    // Must be a UIView or at least act like one
    var screenshot: UIImage { get }
    var layer: CALayer { get }
    var frame: CGRect { get }
    var bounds: CGRect { get }
    var superview: UIView? { get }
    var alpha: CGFloat { get set }
}

protocol DraggableCell: View {
    var containerView: UIView { get }
    var isDraggable: Bool { get }
    var dragItem: Item? { get }
    var indexPath: IndexPath? { get }
}

fileprivate func +(left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x + right.x, y: left.y + right.y)
}

fileprivate func -(left: CGPoint, right: CGPoint) -> CGPoint {
    return CGPoint(x: left.x - right.x, y: left.y - right.y)
}

class DraggableTableView: UITableView {
    
    // MARK: - Notifications -
    
    struct Notifications {
        static let draggingBegan            = Notification.Name("draggingBegan")
        static let draggingMoved            = Notification.Name("draggingMoved")
        static let draggingEnded            = Notification.Name("draggingEnded")
        static let draggingCanceled         = Notification.Name("draggingCanceled")
        static let forceTouchDetectionBegan = Notification.Name("forceTouchDetectionBegan")
        
        struct Keys {
            static let location            = "location"
            static let dragCell            = "dragCell"
            static let dragSourceTableView = "dragSourceTableView"
        }
        
        static func userInfo(location: NSValue, dragSourceTableView: UITableView, dragCell: DraggableCell) -> [String: Any] {
            var userInfo = [String: Any]()
            userInfo[Keys.dragSourceTableView] = dragSourceTableView
            userInfo[Keys.location]            = location
            userInfo[Keys.dragCell]            = dragCell
            return userInfo
        }
    }
    
    // MARK: - Constants -
    
    fileprivate let cellEnableDelay = 1.0
    fileprivate let longPressDelay = 150
    fileprivate let cellDimmedAlpha: CGFloat = 0.6
    fileprivate let maxDragImageOffset: CGFloat = 5.0
    fileprivate let minimumForce: CGFloat = 2.0
    fileprivate let activationForce: CGFloat = 5.0
    
    // MARK: - Public Properties -
    
    var allowForceTouch = true
    var dimDraggedCells = true
    
    fileprivate(set) var isDraggingCell: Bool = false
    fileprivate(set) var dragIndexPath: IndexPath?
    fileprivate(set) var dragCell: DraggableCell?
    fileprivate(set) var dragCellAlpha: CGFloat = 1.0
    fileprivate(set) var dragImageView: UIImageView?
    fileprivate(set) var dragImageTouchOffset = CGPoint.zero
    fileprivate(set) var dragImageOriginalOrigin = CGPoint.zero
    
    // MARK: - Internal Properties -

    fileprivate var longPressTimer: DispatchSourceTimer?
    fileprivate var longPressStartLocation = CGPoint()
    fileprivate var isForceTouchActive = false
    
    var dragImageSuperview: UIView {
        // Use the top level view so we can go between controllers
        return self.window!.rootViewController!.view
    }
    
    // MARK: - Lifecycle -
    
    override init(frame: CGRect, style: UITableViewStyle) {
        super.init(frame: frame, style: style)
        self.setup()
    }
    
    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self.setup()
    }
    
    fileprivate func setup() {
        self.separatorStyle = UITableViewCellSeparatorStyle.singleLine
        self.sectionIndexBackgroundColor = UIColor.clear
    }
    
    // MARK: - Helper Functions -
    
    // MARK: Drag Cell
    
    fileprivate func draggableCell(forTouch touch: UITouch) -> DraggableCell? {
        let point = touch.location(in: self)
        if let indexPath = self.indexPathForRow(at: point), let cell = self.cellForRow(at: indexPath) as? DraggableCell, cell.isDraggable {
            return cell
        }
        return nil
    }
    
    fileprivate func dimDragCell() {
        if dimDraggedCells, let dragCell = dragCell {
            if isForceTouchActive {
                dragCell.containerView.alpha = cellDimmedAlpha
            } else {
                UIView.animate(withDuration: 0.1) {
                    // Undo the cell dimming
                    dragCell.containerView.alpha = self.cellDimmedAlpha
                }
            }
        }
    }
    
    fileprivate func undimDragCell() {
        if dimDraggedCells, let dragCell = dragCell {
            if isForceTouchActive {
                dragCell.containerView.alpha = self.dragCellAlpha
            } else {
                UIView.animate(withDuration: 0.1) {
                    // Undo the cell dimming
                    dragCell.containerView.alpha = self.dragCellAlpha
                }
            }
        }
    }

    // MARK: Drag Image
    
    fileprivate func activateDragging(cell: DraggableCell, animateToOffset offset: CGFloat) {
        self.isScrollEnabled = false
        dragIndexPath = cell.indexPath
        dragCell = cell
        dragCellAlpha = cell.containerView.alpha
        
        createDragImageView(fromCell: cell)
        animateDragImageView(toOffset: offset) {
            self.dimDragCell()
        }
    }
    
    fileprivate func createDragImageView(fromCell cell: DraggableCell) {
        let image = cell.screenshot
        dragImageView = UIImageView(image: image)
        dragImageView?.frame.origin = dragImageSuperview.convert(cell.frame.origin, from: cell.superview)
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
    }
    
    fileprivate func removeDragImageView() {
        dragImageView?.removeFromSuperview()
        dragImageView = nil
    }
    
    fileprivate func animateDragImageView(toOffset offset: CGFloat, duration: TimeInterval = 0.1, additionalAnimations: (()->())? = nil) {
        UIView.animate(withDuration: duration, delay: 0.0, options: .beginFromCurrentState, animations: {
            let origin = self.dragImageOriginalOrigin + CGPoint(x: offset, y: -offset)
            self.dragImageView?.frame.origin = origin
            additionalAnimations?()
        }, completion: nil)
    }
    
    fileprivate func calculateDragImageOffset(force: CGFloat) -> CGFloat {
        return convertToRange(number: force, inputMin: minimumForce, inputMax: activationForce, outputMin: 0, outputMax: maxDragImageOffset)
    }
    
    // MARK: - Touch Handling -
    
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
            
            if let indexPath = self.indexPathForRow(at: point), let cell = self.cellForRow(at: indexPath), cell is DraggableCell {
                dragImageTouchOffset = touch.location(in: cell)
                dragImageOriginalOrigin = dragImageSuperview.convert(cell.frame.origin, from: cell.superview)
                
                if isForceTouchAvailable && allowForceTouch {
                    if touch.force >= minimumForce {
                        forceTouchStarted(touch: touch)
                    }
                } else {
                    scheduleLongPressTimer(cell: cell, windowLocation: touch.location(in: nil))
                }
            }
        }
        
        super.touchesBegan(touches, with: event)
    }
    
    override func touchesMoved(_ touches: Set<UITouch>, with event: UIEvent?) {
        // Cancel the long press and force touch if user moves finger too far
        if let touch = touches.first {
            let point = touch.location(in: self)
            let distance = hypot(longPressStartLocation.x - point.x, longPressStartLocation.y - point.y)
            if distance > 5.0 {
                cancelLongPressTimer()
                if isForceTouchActive {
                    let point = touch.location(in: self)
                    if let indexPath = self.indexPathForRow(at: point), let draggableCell = self.cellForRow(at: indexPath) as? DraggableCell {
                        draggableCell.containerView.alpha = self.dragCellAlpha
                    }
                    
                    isForceTouchActive = false
                    removeDragImageView()
                }
            } else if isForceTouchActive {
                forceTouchForceChanged(touch: touch)
            } else if !isDraggingCell && isForceTouchAvailable && allowForceTouch && touch.force >= minimumForce {
                forceTouchStarted(touch: touch)
            }
        }
        
        // Handle cell dragging
        if isDraggingCell, let dragImageView = dragImageView, let dragCell = dragCell, let touch = touches.first {
            let superviewPoint = touch.location(in: dragImageSuperview)
            dragImageView.frame.origin = superviewPoint - dragImageTouchOffset
            
            let windowPoint = touch.location(in: nil)
            let userInfo = Notifications.userInfo(location: NSValue(cgPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
            NotificationCenter.postOnMainThread(name: Notifications.draggingMoved, userInfo: userInfo)
        }
        
        super.touchesMoved(touches, with: event)
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent?) {
        removeDragImageView()
        cancelLongPressTimer()
        
        if let touch = touches.first {
            if let dragCell = dragCell {
                undimDragCell()
                
                let userInfo = Notifications.userInfo(location: NSValue(cgPoint: touch.location(in: nil)), dragSourceTableView: self, dragCell: dragCell)
                NotificationCenter.postOnMainThread(name: Notifications.draggingEnded, userInfo: userInfo)
            } else {
                // Select the cell if this was not a long press
                let point = touch.location(in: self)
                if !self.isEditing || (self.isEditing && Float(point.x) > 40.0) {
                    if let indexPath = self.indexPathForRow(at: point) {
                        self.selectRow(at: indexPath, animated: false, scrollPosition: .none)
                        self.delegate?.tableView?(self, didSelectRowAt: indexPath)
                    }
                }
            }
        }
        
        self.allowsSelection = true
        self.isScrollEnabled = true
        isDraggingCell = false
        isForceTouchActive = false
        
        super.touchesEnded(touches, with: event)
    }
    
    override func touchesCancelled(_ touches: Set<UITouch>?, with event: UIEvent?) {
        removeDragImageView()
        cancelLongPressTimer()
        
        if let dragCell = dragCell {
            undimDragCell()
            
            var windowPoint = CGPoint.zero
            if let touch = touches?.first {
                windowPoint = touch.location(in: nil)
            }
            
            let userInfo = Notifications.userInfo(location: NSValue(cgPoint: windowPoint), dragSourceTableView: self, dragCell: dragCell)
            NotificationCenter.postOnMainThread(name: Notifications.draggingCanceled, userInfo: userInfo)
        }
        
        self.allowsSelection = true
        self.isScrollEnabled = true
        isDraggingCell = false
        isForceTouchActive = false
        
        super.touchesCancelled(touches!, with: event)
    }
    
    // MARK: - Long Press -
    
    fileprivate func scheduleLongPressTimer(cell: UITableViewCell, windowLocation: CGPoint) {
        cancelLongPressTimer()
        
        if let cell = cell as? DraggableCell {
            longPressTimer = DispatchSource.makeTimerSource(queue: DispatchQueue.main)
            longPressTimer!.scheduleOneshot(deadline: .now() + .milliseconds(longPressDelay), leeway: .nanoseconds(0))
            longPressTimer!.setEventHandler {
                self.longPressFired(cell: cell, windowLocation: windowLocation)
            }
            longPressTimer!.resume()
        }
    }
    
    fileprivate func cancelLongPressTimer() {
        if let longPressTimer = longPressTimer {
            longPressTimer.cancel()
            self.longPressTimer = nil
        }
    }
    
    override func setContentOffset(_ contentOffset: CGPoint, animated: Bool) {
        // Cancel the long press timer if they start scrolling
        cancelLongPressTimer()
        super.setContentOffset(contentOffset, animated: animated)
    }
    
    fileprivate func longPressFired(cell: DraggableCell, windowLocation: CGPoint) {
        isDraggingCell = true
        activateDragging(cell: cell, animateToOffset: maxDragImageOffset)
        
        // Match the animation so movement is smooth
        dragImageTouchOffset.x -= maxDragImageOffset
        dragImageTouchOffset.y += maxDragImageOffset
        
        // Taptic feedback
        tapticFeedback()
        
        let userInfo = Notifications.userInfo(location: NSValue(cgPoint: windowLocation), dragSourceTableView: self, dragCell: dragCell!)
        NotificationCenter.postOnMainThread(name: Notifications.draggingBegan, userInfo: userInfo)
    }
    
    // MARK: - Force Touch -
    
    fileprivate func forceTouchStarted(touch: UITouch) {
        if let draggableCell = draggableCell(forTouch: touch) {
            isForceTouchActive = true
            
            let offset = calculateDragImageOffset(force: touch.force)
            activateDragging(cell: draggableCell, animateToOffset: offset)
            
            NotificationCenter.postOnMainThread(name: Notifications.forceTouchDetectionBegan)
        }
    }
    
    fileprivate func forceTouchForceChanged(touch: UITouch) {
        if isForceTouchActive {
            // Constrain the force value and calculate the offset
            let force = clamp(value: touch.force, lower: minimumForce, upper: activationForce)
            var offset = calculateDragImageOffset(force: force)
            
            // If the force is high enough, activate the drag
            if force >= activationForce {
                tapticFeedback()
                
                offset = maxDragImageOffset
                dragImageTouchOffset.x -= offset
                dragImageTouchOffset.y += offset
                
                isDraggingCell = true
                isForceTouchActive = false
                
                let location = NSValue(cgPoint: touch.location(in: nil))
                let userInfo = Notifications.userInfo(location: location, dragSourceTableView: self, dragCell: dragCell!)
                NotificationCenter.postOnMainThread(name: Notifications.draggingBegan, userInfo: userInfo)
            }
            
            // Lift up the cell
            animateDragImageView(toOffset: offset)
        }
    }
}
