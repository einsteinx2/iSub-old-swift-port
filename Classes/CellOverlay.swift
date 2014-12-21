//
//  CellOverlay.swift
//  iSub
//
//  Created by Benjamin Baron on 12/16/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation

@objc public protocol CellOverlayDelegate {
    func cellOverlayDownloadButtonPressed(overlay: CellOverlay)
    func cellOverlayQueueButtonPressed(overlay: CellOverlay)
    func cellOverlayBlockerButtonPressed(overlay: CellOverlay)
    func cellOverlayDeleteButtonPressed(overlay: CellOverlay)
}

public class CellOverlay : UIView {
    
    let _settings = SavedSettings.sharedInstance()
    
    let _inputBlocker = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    let _downloadButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    let _queueButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    
    public weak var delegate: CellOverlayDelegate?
    
    func _commonInit() {
        self.backgroundColor = UIColor(red: 0, green: 0, blue: 0, alpha: 0.85)
        self.alpha = 0.1
        self.userInteractionEnabled = true
    
        self.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        
        self._inputBlocker.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight
        self._inputBlocker.addTarget(self, action: "a_blockerButton:", forControlEvents: UIControlEvents.TouchUpInside)
        self._inputBlocker.frame = self.frame
        self._inputBlocker.userInteractionEnabled = false
        self.addSubview(self._inputBlocker)
        
        self._downloadButton.autoresizingMask = UIViewAutoresizing.FlexibleLeftMargin | UIViewAutoresizing.FlexibleRightMargin
        self._downloadButton.alpha = 1.0
        self._downloadButton.addTarget(self, action: "a_downloadButton:", forControlEvents: UIControlEvents.TouchUpInside)
        self._downloadButton.userInteractionEnabled = false
        self._downloadButton.frame = CGRectMake(30, 5, 120, 34)
        let downloadWidth = self.frame.size.width == 320 ? 90.0 : (self.frame.size.width / 3.0) - 50.0
        self._downloadButton.center = CGPointMake(downloadWidth, self.frame.size.height / 2)
        self._downloadButton.setTitle("Download", forState: UIControlState.Normal)
        self._downloadButton.setTitleColor(ISMSHeaderButtonColor, forState: UIControlState.Normal)
        self._downloadButton.backgroundColor = UIColor.whiteColor()
        self._downloadButton.layer.cornerRadius = 3.0
        self._downloadButton.layer.masksToBounds = true
        self._inputBlocker.addSubview(self._downloadButton)
        
        // If the cache feature is not unlocked, don't allow the user to cache songs
        if !_settings.isCacheUnlocked {
            self._downloadButton.enabled = false
        }
        
        self._queueButton.autoresizingMask = UIViewAutoresizing.FlexibleLeftMargin | UIViewAutoresizing.FlexibleRightMargin
        self._queueButton.alpha = 1.0
        self._queueButton.addTarget(self, action: "a_queueButton:", forControlEvents: UIControlEvents.TouchUpInside)
        self._queueButton.userInteractionEnabled = false
        self._queueButton.frame = CGRectMake(170, 5, 120, 34)
        let queueWidth = self.frame.size.width == 320 ? 230.0 : ((self.frame.size.width / 3.0) * 2.0) + 40.0
        self._queueButton.center = CGPointMake(queueWidth, self.frame.size.height / 2)
        self._queueButton.setTitle("Queue", forState: UIControlState.Normal)
        self._queueButton.setTitleColor(ISMSHeaderButtonColor, forState: UIControlState.Normal)
        self._queueButton.backgroundColor = UIColor.whiteColor()
        self._queueButton.layer.cornerRadius = 3.0
        self._queueButton.layer.masksToBounds = true
        self._inputBlocker.addSubview(self._queueButton)
        
        // If the playlist feature is not unlocked, don't allow the user to queue songs
        if !_settings.isPlaylistUnlocked {
            self._queueButton.enabled = false
        }
    }
    
    public init(tableCell: UITableViewCell) {
        if let tableCellDelegate = tableCell as? CellOverlayDelegate {
            self.delegate = tableCellDelegate
        }
        
        var frame = tableCell.frame
        frame.origin = CGPointZero
        super.init(frame: frame)
        _commonInit()
    }

    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _commonInit()
    }
    
    // MARK: - Public -
    
    public func enableButtons() {
        self._inputBlocker.userInteractionEnabled = true
        self._downloadButton.userInteractionEnabled = true
        self._queueButton.userInteractionEnabled = true
    }
    
    public func disableDownloadButton() {
        self._downloadButton.alpha = 0.3
        self._downloadButton.enabled = false
    }
    
    public func enableDownloadButton() {
        self._downloadButton.alpha = 1.0
        self._downloadButton.enabled = true
    }
    
    public func disableQueueButton() {
        self._downloadButton.alpha = 0.3
        self._downloadButton.enabled = false
    }
    
    public func enableQueueButton() {
        self._downloadButton.alpha = 1.0
        self._downloadButton.enabled = true
    }
    
    public func showDeleteButton() {
        self._downloadButton.setTitle("Delete", forState:UIControlState.Normal)
        self._downloadButton.titleLabel?.textColor = UIColor.redColor()
        self._downloadButton.addTarget(self, action: "a_deleteButton:", forControlEvents: UIControlEvents.TouchUpInside)
    }
    
    // MARK: - Actions -
    
    func a_blockerButton(sender: AnyObject) {
        self.delegate?.cellOverlayBlockerButtonPressed(self)
    }
    
    func a_downloadButton(sender: AnyObject) {
        self.delegate?.cellOverlayDownloadButtonPressed(self)
    }
    
    func a_queueButton(sender: AnyObject) {
        self.delegate?.cellOverlayQueueButtonPressed(self)
    }
    
    func a_deleteButton(sender: AnyObject) {
        self.delegate?.cellOverlayDeleteButtonPressed(self)
    }
}