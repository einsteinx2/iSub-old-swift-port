//
//  FolderDropdownControl.swift
//  iSub
//
//  Created by Benjamin Baron on 12/21/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

@objc public protocol FolderDropdownControlDelegateSwift {
    func folderDropdownMoveViewsY(y: CGFloat)
    func folderDropdownViewsFinishedMoving()
    func folderDropdownSelectFolder(folderId: Int)
}

public class FolderDropdownControlSwift: UIView {
    
    public weak var delegate: FolderDropdownControlDelegateSwift?
    
    public var folders: [ISMSMediaFolder]? {
        didSet {
            if let folders = folders {
                _didSetFolders(folders)
            }
        }
    }
    
    private var _selectedFolderId: Int = -1
    
    private let _arrowImage = CALayer()
    private var _sizeIncrease: Float = 0.0
    
    private let _selectedFolderLabel = UILabel()
    private var _labels: [UILabel] = []
    
    private var _isOpen: Bool = false
    
    private var _dropdownButton = UIButton(type: .Custom)
    
    // Colors
    private let _borderColor: UIColor = ISMSHeaderTextColor
    private let _textColor: UIColor = ISMSHeaderTextColor
    private let _lightColor: UIColor = UIColor.whiteColor()
    private let _darkColor: UIColor = UIColor.whiteColor()
    
    private func _commonInit() {
        self.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        self.userInteractionEnabled = true
        self.backgroundColor = UIColor.clearColor()
        self.layer.borderColor = _borderColor.CGColor
        self.layer.borderWidth = 2.0
        self.layer.cornerRadius = 8
        self.layer.masksToBounds = true
        
        _selectedFolderLabel.frame = CGRectMake(5, 0, self.frame.size.width - 10, 30)
        _selectedFolderLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        _selectedFolderLabel.userInteractionEnabled = true
        _selectedFolderLabel.backgroundColor = UIColor.clearColor()
        _selectedFolderLabel.textColor = _borderColor
        _selectedFolderLabel.textAlignment = NSTextAlignment.Center
        _selectedFolderLabel.font = ISMSBoldFont(20)
        _selectedFolderLabel.text = "All Folders"
        self.addSubview(_selectedFolderLabel)
        
        let arrowImageView = UIView(frame: CGRectMake(193, 7, 18, 18))
        arrowImageView.autoresizingMask = UIViewAutoresizing.FlexibleLeftMargin
        self.addSubview(arrowImageView)
        
        _arrowImage.frame = CGRectMake(0, 0, 18, 18)
        _arrowImage.contentsGravity = kCAGravityResizeAspect
        _arrowImage.contents = UIImage(named: "folder-dropdown-arrow")?.CGImage
        arrowImageView.layer.addSublayer(_arrowImage)
        
        _dropdownButton.frame = CGRectMake(0, 0, 220, 30)
        _dropdownButton.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        _dropdownButton.addTarget(self, action: "toggleDropdown:", forControlEvents: UIControlEvents.TouchUpInside)
        _dropdownButton.accessibilityLabel = _selectedFolderLabel.text
        _dropdownButton.accessibilityHint = "Switches folders"
        self.addSubview(_dropdownButton)
    }
    
    public init() {
        super.init(frame: CGRectZero)
        _commonInit()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        _commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _commonInit()
    }
  
    private func _didSetFolders(mediaFolders: [ISMSMediaFolder]) {
        // Remove old labels
        for label in _labels {
            label.removeFromSuperview()
        }
        _labels.removeAll()
        
        _sizeIncrease = Float(mediaFolders.count) * 30.0
        
        // Process the names and create the labels/buttons
        var i: CGFloat = 0
        for mediaFolder in mediaFolders {
            
            let name = mediaFolder.name
            let tag = mediaFolder.mediaFolderId
            let labelFrame = CGRectMake(0, (i + 1.0) * 30.0, self.frame.size.width, 30)
            let buttonFrame = CGRectMake(0, 0, labelFrame.size.width, labelFrame.size.height)
            
            let folderLabel = UILabel(frame: labelFrame)
            folderLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth;
            folderLabel.userInteractionEnabled = true
            if i % 2 == 0 {
                folderLabel.backgroundColor = _lightColor
            } else {
                folderLabel.backgroundColor = _darkColor
            }
            folderLabel.textColor = _textColor
            folderLabel.textAlignment = NSTextAlignment.Center
            folderLabel.font = ISMSBoldFont(20)
            folderLabel.text = name
            folderLabel.tag = tag == nil ? 0 : tag!.integerValue
            folderLabel.isAccessibilityElement = false
            self.addSubview(folderLabel)
            _labels.append(folderLabel)
            
            let folderButton = UIButton(type: UIButtonType.Custom)
            folderButton.frame = buttonFrame
            folderButton.autoresizingMask = [.FlexibleWidth, .FlexibleHeight];
            folderButton.accessibilityLabel = folderLabel.text
            folderButton.addTarget(self, action: "selectFolder:", forControlEvents: UIControlEvents.TouchUpInside)
            folderLabel.addSubview(folderButton)
            folderButton.isAccessibilityElement = _isOpen
            
            i++
        }
    }
    
    public func toggleDropdown(sender: AnyObject?) {
        if _isOpen {
            // Close it
            UIView.animateWithDuration(0.25, animations: {
                self.height -= CGFloat(self._sizeIncrease)
                self.delegate?.folderDropdownMoveViewsY(-CGFloat(self._sizeIncrease))
            }, completion: { (finished: Bool) -> Void in
                self.delegate?.folderDropdownViewsFinishedMoving()
                return
            })
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            _arrowImage.transform = CATransform3DMakeRotation((CGFloat(M_PI) / 180.0) * 0.0, 0.0, 0.0, 1.0)
            CATransaction.commit()
        } else {
            // Open it
            UIView.animateWithDuration(0.25, animations: {
                self.height += CGFloat(self._sizeIncrease)
                self.delegate?.folderDropdownMoveViewsY(CGFloat(self._sizeIncrease))
            }, completion: { (finished: Bool) -> Void in
                self.delegate?.folderDropdownViewsFinishedMoving()
                return
            })
            
            CATransaction.begin()
            CATransaction.setAnimationDuration(0.25)
            _arrowImage.transform = CATransform3DMakeRotation((CGFloat(M_PI) / 180.0) * -60.0, 0.0, 0.0, 1.0);
            CATransaction.commit()
        }
        
        _isOpen = !_isOpen
        
        // Remove accessibility when not visible
        for label in _labels {
            for subview in label.subviews as [UIView] {
                if subview is UIButton {
                    subview.isAccessibilityElement = _isOpen
                }
            }
        }
        
        UIAccessibilityPostNotification(UIAccessibilityLayoutChangedNotification, nil);
    }
    
    public func closeDropdown() {
        if _isOpen {
            self.toggleDropdown(nil)
        }
    }
    
    public func closeDropdownFast() {
        if _isOpen {
            _isOpen = false
            
            self.height -= CGFloat(_sizeIncrease)
            self.delegate?.folderDropdownMoveViewsY(-CGFloat(_sizeIncrease))
            
            _arrowImage.transform = CATransform3DMakeRotation((CGFloat(M_PI) / 180.0) * 0.0, 0.0, 0.0, 1.0)
            
            self.delegate?.folderDropdownViewsFinishedMoving()
        }
    }

    public func selectFolder(sender: UIButton)
    {
        if let label = sender.superview as? UILabel {
            _selectedFolderId = label.tag
            self.selectFolderWithId(_selectedFolderId)
            self.closeDropdownFast()
            
            // Call the delegate method
            self.delegate?.folderDropdownSelectFolder(_selectedFolderId)
        }
    }
    
    public func selectFolderWithId(folderId: Int) {
        _selectedFolderId = folderId
        
        if let folders = folders {
            let folder = folders.filter { e in e.mediaFolderId == folderId }
            if folder.count > 0 {
                _selectedFolderLabel.text = folder[0].name
                _dropdownButton.accessibilityLabel = _selectedFolderLabel.text
            }
        }
    }
}