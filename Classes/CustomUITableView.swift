//
//  CustomUITableView.swift
//  iSub
//
//  Created by Benjamin Baron on 12/20/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class CustomUITableView: UITableView {
    
    let HorizSwipeDragMin: Double = 3.0
    let VertSwipeDragMax: Double = 80.0
    
    let CellEnableDelay: NSTimeInterval = 1.0
    let TapAndHoldDelay: NSTimeInterval = 0.25
    
    let _settings = SavedSettings.sharedInstance()

    var _startTouchPosition: CGPoint?
    var _swiped: Bool = false
    var _cellShowingOverlay: UITableViewCell?
    var _tapAndHoldCell: UITableViewCell?
    var _lastDeleteToggle: NSDate = NSDate()
    
    var _tapAndHoldTimer: NSTimer?
    
    private func _setup() {
        self.separatorStyle = UITableViewCellSeparatorStyle.SingleLine
        self.sectionIndexBackgroundColor = UIColor.clearColor()
    }
    
    public override init() {
        super.init()
        self._setup()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        self._setup()
    }
    
    public override init(frame: CGRect, style: UITableViewStyle) {
        super.init(frame: frame, style: style)
        self._setup()
    }
    
    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        self._setup()
    }
    
    // MARK: - Touch Gestures Interception -
    
    private func _hideAllOverlays(cellToSkip: UITableViewCell?) {
        for cell in self.visibleCells() as [UITableViewCell] {
            if let customCell: CustomUITableViewCell = cell as? CustomUITableViewCell {
                if customCell != cellToSkip {
                    customCell.hideOverlay()
                }
            }
        }
    }
    
    public override func hitTest(point: CGPoint, withEvent event: UIEvent?) -> UIView? {
        // Don't try anything when the tableview is moving and do not catch as a swipe if touch is far right (potential index control)
        if !self.decelerating && point.x < 290 {
            
            // Find the cell
            if let indexPath = self.indexPathForRowAtPoint(point) {
                
                if let cell = self.cellForRowAtIndexPath(indexPath) {
                    
                    // TODO: Move multi delete touch handling to CustomUITableViewCell
                    
                    // Handle multi delete touching
                    if self.editing && point.x < 40.0 && NSDate().timeIntervalSinceDate(self._lastDeleteToggle) > 0.25 {
                        self._lastDeleteToggle = NSDate()
                        if let customCell: CustomUITableViewCell = cell as? CustomUITableViewCell {
                            customCell.toggleDelete()
                        }
                    }
                    
                    // Remove overlays
                    if !self._swiped {
                        self._hideAllOverlays(cell)
                        
                        if let customCell: CustomUITableViewCell = cell as? CustomUITableViewCell {
                            if customCell.overlayShowing {
                                EX2Dispatch.runInMainThreadAfterDelay(1.0, {
                                    customCell.hideOverlay()
                                })
                            }
                        }
                    }
                }
            }
        }
        
        return super.hitTest(point, withEvent: event)
    }
    
    public override func touchesShouldCancelInContentView(view: UIView!) -> Bool {
        return true
    }
    
    public override func touchesShouldBegin(touches: NSSet!, withEvent event: UIEvent!, inContentView view: UIView!) -> Bool {
        return true
    }
    
    // MARK: - Touch gestures for custom cell view -
    
    private func _disableCellsTemporarily() {
        self.allowsSelection = false
        EX2Dispatch.runInMainThreadAfterDelay(CellEnableDelay, {
            self.allowsSelection = true
        })
    }
    
    private func _isTouchHorizontal(touch: UITouch) -> Bool
    {
        let currentTouchPosition: CGPoint = touch.locationInView(self)
        if let startTouchPosition = self._startTouchPosition? {
            let xMovement = fabs(Double(startTouchPosition.x) - Double(currentTouchPosition.x))
            let yMovement = fabs(Double(startTouchPosition.y) - Double(currentTouchPosition.y))
            
            return xMovement > yMovement
        }
        
        return false
    }
    
    private func _lookForSwipeGestureInTouches(touches: NSSet, event: UIEvent)
    {
        var cell: UITableViewCell? = nil
        
        let currentTouchPosition: CGPoint? = touches.anyObject()?.locationInView(self)
        if currentTouchPosition != nil {
            let indexPath: NSIndexPath? = self.indexPathForRowAtPoint(currentTouchPosition!)
            if indexPath != nil {
                cell = self.cellForRowAtIndexPath(indexPath!)
            }
        }
        
        if (!self._swiped && cell != nil)
        {
            // Check if this is a full swipe
            if let startTouchPosition: CGPoint = self._startTouchPosition? {
                
                let startTouchX = Double(startTouchPosition.x)
                let startTouchY = Double(startTouchPosition.y)
                let currentTouchX = Double(currentTouchPosition!.x)
                let currentTouchY = Double(currentTouchPosition!.y)
                
                let xDiff = fabs(startTouchX - currentTouchX)
                let yDiff = fabs(startTouchY - currentTouchY)
                
                if xDiff >= HorizSwipeDragMin && yDiff <= VertSwipeDragMax {
                        self._swiped = true
                        self.scrollEnabled = false
                        
                        // Temporarily disable the cells so we don't get accidental selections
                        self._disableCellsTemporarily()
                        
                        // Hide any open overlays
                        self._hideAllOverlays(nil)
                        
                        // Detect the direction
                        if startTouchX < currentTouchX {
                            // Right swipe
                            if _settings.isSwipeEnabled && !IS_IPAD() {
                                if let customCell = cell as? CustomUITableViewCell {
                                    customCell.showOverlay()
                                }
                                
                                self._cellShowingOverlay = cell
                            }
                        } else {
                            // Left Swipe
                            if let customCell = cell as? CustomUITableViewCell {
                                customCell.scrollLabels()
                            }
                        }
                } else {
                    // Process a non-swipe event.
                }
            }
        }
    }
    
    public func _tapAndHoldFired() {
        self._swiped = true
        if let customCell: CustomUITableViewCell = self._tapAndHoldCell as? CustomUITableViewCell {
            customCell.showOverlay()
        }
        self._cellShowingOverlay = self._tapAndHoldCell
    }
    
    private func _cancelTapAndHold() {
        _tapAndHoldTimer?.invalidate();
        _tapAndHoldTimer = nil
    }
    
    public override func touchesBegan(touches: NSSet, withEvent event: UIEvent) {
        self.allowsSelection = false
        self.scrollEnabled = true
        
        // Handle swipe
        self._startTouchPosition = touches.anyObject()!.locationInView(self)
        self._swiped = false
        self._cellShowingOverlay = nil
        
        // Handle tap and hold
        if (_settings.isTapAndHoldEnabled) {
            let indexPath = self.indexPathForRowAtPoint(self._startTouchPosition!)
            if let indexPath = indexPath? {
                self._tapAndHoldCell = self.cellForRowAtIndexPath(indexPath)
                
                _tapAndHoldTimer = NSTimer.scheduledTimerWithTimeInterval(TapAndHoldDelay, target: self, selector: "_tapAndHoldFired", userInfo: nil, repeats: false);
            }
        }
        
        super.touchesBegan(touches, withEvent: event)
    }
    
    public override func touchesMoved(touches: NSSet, withEvent event: UIEvent) {
        // Cancel the tap and hold if user moves finger
        self._cancelTapAndHold()
        
        // Check for swipe
        if self._isTouchHorizontal(touches.anyObject()! as UITouch) {
            self._lookForSwipeGestureInTouches(touches, event: event)
        }
        
        super.touchesMoved(touches, withEvent: event)
    }

    public override func touchesEnded(touches: NSSet, withEvent event: UIEvent) {
        self.allowsSelection = true
        self.scrollEnabled = true
        
        self._cancelTapAndHold()
        
        if self._swiped {
            // Enable the buttons if the overlay is showing
            if let customCell: CustomUITableViewCell = self._cellShowingOverlay as? CustomUITableViewCell {
                customCell.overlayView?.enableButtons();
            }
        } else {
            // Select the cell if this was a touch not a swipe or tap and hold
            let currentTouchPosition = touches.anyObject()!.locationInView(self)
            if (self.editing && Float(currentTouchPosition.x) > 40.0) || !self.editing {
                let indexPath: NSIndexPath? = self.indexPathForRowAtPoint(currentTouchPosition)
                
                if indexPath != nil {
                    self.selectRowAtIndexPath(indexPath, animated: false, scrollPosition: UITableViewScrollPosition.None)
                    if let delegate: UITableViewDelegate = self.delegate? {
                        delegate.tableView?(self, didSelectRowAtIndexPath: indexPath!)
                    }
                }
            }
        }
        self._swiped = false
        
        super.touchesEnded(touches, withEvent: event)
    }
    
    public override func touchesCancelled(touches: NSSet!, withEvent event: UIEvent!) {
        self._cancelTapAndHold()
        
        self.allowsSelection = true
        self.scrollEnabled = true
        self._swiped = false
        
        if let customCell: CustomUITableViewCell = self._cellShowingOverlay as? CustomUITableViewCell {
            customCell.overlayView?.enableButtons();
        }
        
        super.touchesCancelled(touches, withEvent: event)
    }
}
