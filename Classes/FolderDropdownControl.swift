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
    
    public var folders: NSDictionary? = SUSRootFoldersDAO.folderDropdownFolders() {
        didSet {
            _setFolders(folders)
        }
    }
    
    private var _selectedFolderId: Int = -1
    
    private let _arrowImage = CALayer()
    private var _sizeIncrease: Float = 0.0
    
    private let _selectedFolderLabel = UILabel()
    private var _labels: [UILabel] = []
    
    private var _isOpen: Bool = false
    
    private var _dropdownButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
    
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
        
        updateFolders()
    }
    
    public override init() {
        super.init()
        _commonInit()
    }
    
    public override init(frame: CGRect) {
        super.init(frame: frame)
        _commonInit()
    }

    public required init(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _commonInit()
    }
  
    private func _setFolders(namesAndIds: NSDictionary?) {
        // Remove old labels
        for label in _labels {
            label.removeFromSuperview()
        }
        _labels.removeAll()
        
        let count = self.folders == nil ? 0 : self.folders!.count
        _sizeIncrease = Float(count) * 30.0
        
        var sortedValues: [(id: Int, name: String)] = []
        for key in self.folders?.allKeys as [Int] {
            if key != -1 {
                sortedValues.append(id: key, name: self.folders?[key] as String)
            }
        }
        
        // Sort by folder name
        sortedValues.sort {
            let folder1 = $0.name
            let folder2 = $1.name
            return folder1.caseInsensitiveCompare(folder2) == NSComparisonResult.OrderedDescending
        }
        
        // Add All Folders again
        sortedValues.insert((-1, "All Folders"), atIndex: 0)
        
        // Process the names and create the labels/buttons
        var i: CGFloat = 0
        for folder in sortedValues {
            
            let name = folder.name
            let tag = folder.id
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
            folderLabel.tag = tag
            folderLabel.isAccessibilityElement = false
            self.addSubview(folderLabel)
            _labels.append(folderLabel)
            
            let folderButton = UIButton.buttonWithType(UIButtonType.Custom) as UIButton
            folderButton.frame = buttonFrame
            folderButton.autoresizingMask = UIViewAutoresizing.FlexibleWidth | UIViewAutoresizing.FlexibleHeight;
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
            _selectedFolderLabel.text = self.folders?[_selectedFolderId] as? String
            _dropdownButton.accessibilityLabel = _selectedFolderLabel.text;
            self.closeDropdownFast()
            
            // Call the delegate method
            self.delegate?.folderDropdownSelectFolder(_selectedFolderId)
        }
    }
    
    public func selectFolderWithId(folderId: Int) {
        _selectedFolderId = folderId
        _selectedFolderLabel.text = self.folders?[_selectedFolderId] as? String
        _dropdownButton.accessibilityLabel = _selectedFolderLabel.text
    }
    
    public func updateFolders() {
        let loader: ISMSDropdownFolderLoader = ISMSDropdownFolderLoader.loaderWithCallbackBlock({ (success: Bool, error: NSError!, loader: ISMSLoader!) -> Void in
            let loader = loader as ISMSDropdownFolderLoader
            if success {
                self.folders = loader.updatedfolders
                SUSRootFoldersDAO.setFolderDropdownFolders(self.folders)
            }
            else
            {
                // failed.  how to report this to the user?
            }
        }) as ISMSDropdownFolderLoader;
        
        loader.startLoad()
        
        // Save the default
        SUSRootFoldersDAO.setFolderDropdownFolders(self.folders)
    }
}