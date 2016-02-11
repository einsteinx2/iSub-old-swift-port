//
//  ItemUITableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 12/16/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

// TODO: Prevent download button in overlay view from being enabled if song is downloaded already

// TODO: Load default cover art image or cached cover art image if available

import libSub
import Foundation
import UIKit

@objc public protocol NewItemUITableViewCellDelegate {
    optional func tableCellDeleteButtonPressed(cell: NewItemUITableViewCell)
    optional func tableCellDeleteToggled(cell: NewItemUITableViewCell, markedForDelete: Bool)
}

public class NewItemUITableViewCell : UITableViewCell {
    
    // Disabled for now until optimized
    let _shouldRepositionLabels = false
    
    let _viewObjects = ViewObjectsSingleton.sharedInstance()
    
    public weak var delegate: NewItemUITableViewCellDelegate?
    public var associatedObject: AnyObject?
    
    public var indexShowing: Bool = false
    public var overlayShowing: Bool = false
    public var overlayDisabled: Bool = false
    
    public var overlayView: CellOverlay?
    
    public var indexPath: NSIndexPath?
    
    public var searching: Bool = false
    
    public let deleteToggleImageView = UIImageView(image: UIImage(named: "unselected"))
    
    public var markedForDelete: Bool = false {
        didSet {
            self._updateDeleteCheckboxImage()
        }
    }
    
    public var showDeleteButton: Bool = false
    
    public var alwaysShowCoverArt: Bool = false
    public var alwaysShowSubtitle: Bool = false
    
    public var coverArtId: String? {
        didSet {
            self._coverArtView.coverArtId = self.coverArtId
            if _shouldRepositionLabels { self._repositionLabels() }
        }
    }

    public var trackNumber: NSNumber? {
        didSet {
            if let trackNumber = trackNumber {
                self._trackNumberLabel.text = "\(trackNumber)"
            }
            if _shouldRepositionLabels { _repositionLabels() }
        }
    }
    
    public var headerTitle: String? {
        didSet {
            self._headerTitleLabel.text = self.headerTitle
            if _shouldRepositionLabels { _repositionLabels() }
        }
    }
    
    public var title: String? {
        didSet {
            self._titleLabel.text = self.title
            if _shouldRepositionLabels { _repositionLabels() }
        }
    }
    
    public var subTitle: String? {
        didSet {
            self._subTitleLabel.text = self.subTitle
            if _shouldRepositionLabels { _repositionLabels() }
        }
    }
    
    public var duration: NSNumber? {
        didSet {
            if let duration = duration {
                self._durationLabel.text = NSString.formatTime(duration.doubleValue)
            }
            if _shouldRepositionLabels { _repositionLabels() }
        }
    }
    
    public var playing: Bool = false {
        didSet {
            self._nowPlayingImageView.hidden = !self.playing
            if self.trackNumber != nil {
                self._trackNumberLabel.hidden = self.playing
            }
        }
    }
    
    private let _coverArtView = AsynchronousImageView()
    private let _trackNumberLabel = UILabel()
    private let _headerTitleLabel = UILabel()
    private let _titlesScrollView = UIScrollView()
    private let _titleLabel = UILabel()
    private let _subTitleLabel = UILabel()
    private let _durationLabel = UILabel()
    private let _nowPlayingImageView = UIImageView(image: UIImage(named: "playing-cell-icon"))
    
    // MARK: - Lifecycle -
    
    private func _commonInit() {
        self.addSubview(self.deleteToggleImageView)
        self.deleteToggleImageView.alpha = 0.0
        
        self._coverArtView.isLarge = false
        self.contentView.addSubview(_coverArtView)
        
        self._trackNumberLabel.backgroundColor = UIColor.clearColor()
        self._trackNumberLabel.textAlignment = NSTextAlignment.Center
        self._trackNumberLabel.font = ISMSBoldFont(22)
        self._trackNumberLabel.adjustsFontSizeToFitWidth = true
        self._trackNumberLabel.minimumScaleFactor = 16.0 / _trackNumberLabel.font.pointSize
        self.contentView.addSubview(self._trackNumberLabel)
        
        self._nowPlayingImageView.hidden = true
        self.contentView.addSubview(self._nowPlayingImageView)
        
        self._headerTitleLabel.textAlignment = NSTextAlignment.Center
        self._headerTitleLabel.backgroundColor = UIColor.blackColor()
        self._headerTitleLabel.alpha = 0.65
        self._headerTitleLabel.font = ISMSBoldFont(10)
        self._headerTitleLabel.textColor = UIColor.whiteColor()
        self.contentView.addSubview(self._headerTitleLabel)
        
        self._titlesScrollView.frame = CGRectMake(35, 0, 235, 50)
        self._titlesScrollView.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        self._titlesScrollView.showsVerticalScrollIndicator = false
        self._titlesScrollView.showsHorizontalScrollIndicator = false
        self._titlesScrollView.userInteractionEnabled = false
        self._titlesScrollView.decelerationRate = UIScrollViewDecelerationRateFast
        self.contentView.addSubview(self._titlesScrollView)
        
        self._titleLabel.backgroundColor = UIColor.clearColor()
        self._titleLabel.textAlignment = NSTextAlignment.Left
        self._titleLabel.font = ISMSSongFont
        self._titlesScrollView.addSubview(self._titleLabel)
        
        self._subTitleLabel.backgroundColor = UIColor.clearColor()
        self._subTitleLabel.textAlignment = NSTextAlignment.Left
        self._subTitleLabel.font = ISMSRegularFont(13)
        self._subTitleLabel.textColor = UIColor(white: 0.4, alpha: 1.0)
        self._titlesScrollView.addSubview(self._subTitleLabel)
        
        self._durationLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        self._durationLabel.backgroundColor = UIColor.clearColor()
        self._durationLabel.textAlignment = NSTextAlignment.Right
        self._durationLabel.font = ISMSRegularFont(16)
        self._durationLabel.adjustsFontSizeToFitWidth = true
        self._durationLabel.minimumScaleFactor = 12.0 / self._durationLabel.font.pointSize
        self._durationLabel.textColor = UIColor.grayColor()
        self.contentView.addSubview(self._durationLabel)
    }
    
    public override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        _commonInit()
    }

    public required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        _commonInit()
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        let oldFrame = self.deleteToggleImageView.frame
        let newY = (self.frame.size.height / 2.0) - (oldFrame.size.height / 2.0)
        self.deleteToggleImageView.frame = CGRectMake(5.0, newY, oldFrame.size.width, oldFrame.size.height)
        
        self._repositionLabels()
    }
    
    // MARK - Public -

    public func showOverlay() {
        if !self.overlayShowing && !self.overlayDisabled {
            self.overlayView = CellOverlay(tableCell: self)
            self.contentView.addSubview(self.overlayView!)
            
            if self.showDeleteButton {
                self.overlayView?.showDeleteButton();
            }
            
            UIView.animateWithDuration(0.25, animations: {
                self.overlayView?.alpha = 1.0
                return
            })
            
            self.overlayShowing = true
        }
    }
    
    public func hideOverlay() {
        self.overlayShowing = false
        UIView.animateWithDuration(1.0, animations: {
                self.overlayView?.alpha = 0.0
                return
            },
            completion:  { (finished: Bool) in
                if !self.overlayShowing {
                    self.overlayView?.removeFromSuperview()
                    self.overlayView = nil
                }
            }
        )
    }
    
    public func scrollLabels() {
        let titleWidth = self._titleLabel.frame.size.width
        let subTitleWidth = self._subTitleLabel.frame.size.width
        let scrollViewWidth = self._titlesScrollView.frame.size.width
        
        let longestTitleWidth = titleWidth > subTitleWidth ? titleWidth : subTitleWidth
        
        if longestTitleWidth > scrollViewWidth {
            let duration: NSTimeInterval = NSTimeInterval(titleWidth) / 150.0
            
            UIView.animateWithDuration(duration, animations: {
                self._titlesScrollView.contentOffset = CGPointMake(longestTitleWidth - scrollViewWidth + 10, 0)
            }, completion: { (finished: Bool) in
                UIView.animateWithDuration(duration, animations: {
                    self._titlesScrollView.contentOffset = CGPointZero
                })
            })
        }
    }

    public func showDeleteCheckbox() {
        // Use alpha to allow animation
        self.deleteToggleImageView.alpha = 1.0;
    }
    
    public func hideDeleteCheckbox() {
        self.deleteToggleImageView.alpha = 0.0;
    }
    
    private func _updateDeleteCheckboxImage() {
        if self.markedForDelete {
            self.deleteToggleImageView.image = UIImage(named: "selected")
            
        } else {
            self.deleteToggleImageView.image = UIImage(named: "unselected")
        }
    }
    
    public func toggleDelete() {
        if let _ = self.indexPath {
            self.markedForDelete = !self.markedForDelete
            
            self.delegate?.tableCellDeleteToggled?(self, markedForDelete: self.markedForDelete)
            
            self._updateDeleteCheckboxImage()
            
            if self.markedForDelete {
                NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_ShowDeleteButton)
                
            } else {
                NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_HideDeleteButton)
            }
        }
    }
    
    // MARK - Private -
    
    // Automatically hide and show labels based on whether we have data for them, then reposition the others to fit
    func _repositionLabels() {
        
        let cellWidth: CGFloat = self.frame.size.width
        let cellHeight: CGFloat = self.frame.size.height
        let spacer: CGFloat = 2.0
        
        self._coverArtView.hidden = true
        self._trackNumberLabel.hidden = true
        self._headerTitleLabel.hidden = true
        self._titleLabel.hidden = true
        self._subTitleLabel.hidden = true
        self._durationLabel.hidden = true
        
        var scrollViewFrame = CGRectMake((spacer * 3), 0, cellWidth - (spacer * 6), cellHeight)
        if self.accessoryType == UITableViewCellAccessoryType.DisclosureIndicator {
            scrollViewFrame.size.width -= 27.0
        }
        
        if let _ = self.headerTitle {
            self._headerTitleLabel.hidden = false
            
            let height: CGFloat = 20.0
            self._headerTitleLabel.frame = CGRectMake(0, 0, cellWidth, height)
            
            scrollViewFrame.size.height -= height
            scrollViewFrame.origin.y += height
        }
        
        let scrollViewHeight = scrollViewFrame.size.height
        
        if let _ = self.title {
            self._titleLabel.hidden = false
            
            let height = self.subTitle == nil ? scrollViewHeight : scrollViewHeight * 0.60
            let expectedLabelSize: CGSize = self._titleLabel.text!.boundingRectWithSize(CGSizeMake(1000, height), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: self._titleLabel.font], context: nil).size
            
            self._titleLabel.frame = CGRectMake(0, 0, expectedLabelSize.width, height)
        }
        
        if self.alwaysShowSubtitle || self.subTitle != nil {
            self._subTitleLabel.hidden = false
            
            let y = scrollViewHeight * 0.57
            let height = scrollViewHeight * 0.33
            let text = self._subTitleLabel.text == nil ? "" : self._subTitleLabel.text!
            let expectedLabelSize = text.boundingRectWithSize(CGSizeMake(1000, height), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: self._subTitleLabel.font], context: nil).size
            
            self._subTitleLabel.frame = CGRectMake(0, y, expectedLabelSize.width, height)
        }
        
        if self.alwaysShowCoverArt || self.coverArtId != nil {
            self._coverArtView.hidden = false
            self._trackNumberLabel.hidden = true
            self._coverArtView.frame = CGRectMake(0, cellHeight - scrollViewHeight, scrollViewHeight, scrollViewHeight)
            scrollViewFrame.size.width -= scrollViewHeight
            scrollViewFrame.origin.x += scrollViewHeight
        } else {
            if let _ = self.trackNumber {
                self._trackNumberLabel.hidden = self.playing
                self._nowPlayingImageView.hidden = !self.playing
                let width: CGFloat = 30.0
                self._trackNumberLabel.frame = CGRectMake(0, cellHeight - scrollViewHeight, width, scrollViewHeight)
                scrollViewFrame.size.width -= width
                scrollViewFrame.origin.x += width
                
                self._nowPlayingImageView.center = self._trackNumberLabel.center
            }
        }
        
        if let _ = self.duration {
            self._durationLabel.hidden = false
            let width: CGFloat = 45.0
            self._durationLabel.frame = CGRectMake(cellWidth - width - (spacer * 3),
                                                   cellHeight - scrollViewHeight,
                                                   width,
                                                   scrollViewHeight)
            scrollViewFrame.size.width -= (width + (spacer * 3))
        }
        
        self._titlesScrollView.frame = scrollViewFrame
    }
}