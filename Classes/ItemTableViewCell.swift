//
//  ItemTableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 12/16/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

// TODO: Load default cover art image or cached cover art image if available

import Foundation
import UIKit

@objc protocol ItemTableViewCellDelegate {
    optional func tableCellDeleteButtonPressed(cell: ItemTableViewCell)
    optional func tableCellDeleteToggled(cell: ItemTableViewCell, markedForDelete: Bool)
}

class ItemTableViewCell: DroppableCell {
    
    var indexPath: NSIndexPath? {
        get {
            return self.tableView?.indexPathForCell(self)
        }
    }
    
    // Disabled for now until optimized
    let shouldRepositionLabels = false
    
    let viewObjects = ViewObjectsSingleton.sharedInstance()
    
    weak var delegate: ItemTableViewCellDelegate?
    var associatedObject: AnyObject?
    
    var indexShowing = false
    
    var searching = false
    
    let deleteToggleImageView = UIImageView(image: UIImage(named: "unselected"))
    
    var markedForDelete = false {
        didSet {
            updateDeleteCheckboxImage()
        }
    }
    
    var showDeleteButton = false
    
    var alwaysShowCoverArt = false
    var alwaysShowSubtitle = false
    
    var coverArtId: String? {
        didSet {
            coverArtView.coverArtId = coverArtId
            if shouldRepositionLabels {
                repositionLabels()
            }
        }
    }

    var trackNumber: NSNumber? {
        didSet {
            if let trackNumber = trackNumber {
                trackNumberLabel.text = "\(trackNumber)"
            }
            if shouldRepositionLabels {
                repositionLabels()
            }
        }
    }
    
    var headerTitle: String? {
        didSet {
            headerTitleLabel.text = headerTitle
            if shouldRepositionLabels {
                repositionLabels()
            }
        }
    }
    
    var title: String? {
        didSet {
            titleLabel.text = title
            if shouldRepositionLabels {
                repositionLabels()
            }
        }
    }
    
    var subTitle: String? {
        didSet {
            subTitleLabel.text = subTitle
            if shouldRepositionLabels {
                repositionLabels()
            }
        }
    }
    
    var duration: NSNumber? {
        didSet {
            if let duration = duration {
                durationLabel.text = NSString.formatTime(duration.doubleValue)
            }
            if shouldRepositionLabels {
                repositionLabels()
            }
        }
    }
    
    var playing: Bool = false {
        didSet {
            nowPlayingImageView.hidden = !playing
            if trackNumber != nil {
                trackNumberLabel.hidden = playing
            }
        }
    }
    
    private let coverArtView = AsynchronousImageView()
    private let trackNumberLabel = UILabel()
    private let headerTitleLabel = UILabel()
    private let titlesScrollView = UIScrollView()
    private let titleLabel = UILabel()
    private let subTitleLabel = UILabel()
    private let durationLabel = UILabel()
    private let nowPlayingImageView = UIImageView(image: UIImage(named: "playing-cell-icon"))
    
    // MARK: - Lifecycle -
    
    private func commonInit() {
        deleteToggleImageView.alpha = 0.0
        containerView.addSubview(deleteToggleImageView)
        
        coverArtView.large = false
        containerView.addSubview(coverArtView)
        
        trackNumberLabel.backgroundColor = UIColor.clearColor()
        trackNumberLabel.textAlignment = NSTextAlignment.Center
        trackNumberLabel.font = ISMSBoldFont(22)
        trackNumberLabel.adjustsFontSizeToFitWidth = true
        trackNumberLabel.minimumScaleFactor = 16.0 / trackNumberLabel.font.pointSize
        containerView.addSubview(trackNumberLabel)
        
        nowPlayingImageView.hidden = true
        containerView.addSubview(nowPlayingImageView)
        
        headerTitleLabel.textAlignment = NSTextAlignment.Center
        headerTitleLabel.backgroundColor = UIColor.blackColor()
        headerTitleLabel.alpha = 0.65
        headerTitleLabel.font = ISMSBoldFont(10)
        headerTitleLabel.textColor = UIColor.whiteColor()
        containerView.addSubview(headerTitleLabel)
        
        titlesScrollView.frame = CGRectMake(35, 0, 235, 50)
        titlesScrollView.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        titlesScrollView.showsVerticalScrollIndicator = false
        titlesScrollView.showsHorizontalScrollIndicator = false
        titlesScrollView.userInteractionEnabled = false
        titlesScrollView.decelerationRate = UIScrollViewDecelerationRateFast
        containerView.addSubview(titlesScrollView)
        
        titleLabel.backgroundColor = UIColor.clearColor()
        titleLabel.textAlignment = NSTextAlignment.Left
        titleLabel.font = ISMSSongFont
        titlesScrollView.addSubview(titleLabel)
        
        subTitleLabel.backgroundColor = UIColor.clearColor()
        subTitleLabel.textAlignment = NSTextAlignment.Left
        subTitleLabel.font = ISMSRegularFont(13)
        subTitleLabel.textColor = UIColor(white: 0.4, alpha: 1.0)
        titlesScrollView.addSubview(subTitleLabel)
        
        durationLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth
        durationLabel.backgroundColor = UIColor.clearColor()
        durationLabel.textAlignment = NSTextAlignment.Right
        durationLabel.font = ISMSRegularFont(16)
        durationLabel.adjustsFontSizeToFitWidth = true
        durationLabel.minimumScaleFactor = 12.0 / durationLabel.font.pointSize
        durationLabel.textColor = UIColor.grayColor()
        containerView.addSubview(durationLabel)
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        commonInit()
    }

    required init?(coder aDecoder: NSCoder) {
        super.init(coder: aDecoder)
        commonInit()
    }
    
    override func layoutSubviews() {
        super.layoutSubviews()
        
        let oldFrame = deleteToggleImageView.frame
        let newY = (cellHeight / 2.0) - (oldFrame.size.height / 2.0)
        deleteToggleImageView.frame = CGRectMake(5.0, newY, oldFrame.size.width, oldFrame.size.height)
        
        repositionLabels()
    }
    
    // MARK: - Public -

    func scrollLabels() {
        let titleWidth = titleLabel.frame.size.width
        let subTitleWidth = subTitleLabel.frame.size.width
        let scrollViewWidth = titlesScrollView.frame.size.width
        
        let longestTitleWidth = titleWidth > subTitleWidth ? titleWidth : subTitleWidth
        
        if longestTitleWidth > scrollViewWidth {
            let duration: NSTimeInterval = NSTimeInterval(titleWidth) / 150.0
            
            UIView.animateWithDuration(duration, animations: {
                self.titlesScrollView.contentOffset = CGPointMake(longestTitleWidth - scrollViewWidth + 10, 0)
            }, completion: { (finished: Bool) in
                UIView.animateWithDuration(duration, animations: {
                    self.titlesScrollView.contentOffset = CGPointZero
                })
            })
        }
    }

    func showDeleteCheckbox() {
        // Use alpha to allow animation
        deleteToggleImageView.alpha = 1.0;
    }
    
    func hideDeleteCheckbox() {
        deleteToggleImageView.alpha = 0.0;
    }
    
    private func updateDeleteCheckboxImage() {
        if markedForDelete {
            deleteToggleImageView.image = UIImage(named: "selected")
            
        } else {
            deleteToggleImageView.image = UIImage(named: "unselected")
        }
    }
    
    func toggleDelete() {
        if indexPath != nil {
            markedForDelete = !markedForDelete
            
            delegate?.tableCellDeleteToggled?(self, markedForDelete: markedForDelete)
            
            updateDeleteCheckboxImage()
            
            if markedForDelete {
                NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_ShowDeleteButton)
                
            } else {
                NSNotificationCenter.postNotificationToMainThreadWithName(ISMSNotification_HideDeleteButton)
            }
        }
    }
    
    // MARK: - Private -
    
    // Automatically hide and show labels based on whether we have data for them, then reposition the others to fit
    func repositionLabels() {
        
        let cellWidth: CGFloat = self.frame.size.width
        let spacer: CGFloat = 2.0
        
        coverArtView.hidden = true
        trackNumberLabel.hidden = true
        headerTitleLabel.hidden = true
        titleLabel.hidden = true
        subTitleLabel.hidden = true
        durationLabel.hidden = true
        
        var scrollViewFrame = CGRectMake((spacer * 3), 0, cellWidth - (spacer * 6), cellHeight)
        if self.accessoryType == UITableViewCellAccessoryType.DisclosureIndicator {
            scrollViewFrame.size.width -= 27.0
        }
        
        if headerTitle != nil {
            headerTitleLabel.hidden = false
            
            let height: CGFloat = 20.0
            headerTitleLabel.frame = CGRectMake(0, 0, cellWidth, height)
            
            scrollViewFrame.size.height -= height
            scrollViewFrame.origin.y += height
        }
        
        let scrollViewHeight = scrollViewFrame.size.height
        
        if title != nil {
            titleLabel.hidden = false
            
            let height = subTitle == nil ? scrollViewHeight : scrollViewHeight * 0.60
            let expectedLabelSize: CGSize = titleLabel.text!.boundingRectWithSize(CGSizeMake(1000, height), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: titleLabel.font], context: nil).size
            
            titleLabel.frame = CGRectMake(0, 0, expectedLabelSize.width, height)
        }
        
        if alwaysShowSubtitle || subTitle != nil {
            subTitleLabel.hidden = false
            
            let y = scrollViewHeight * 0.57
            let height = scrollViewHeight * 0.33
            let text = subTitleLabel.text == nil ? "" : subTitleLabel.text!
            let expectedLabelSize = text.boundingRectWithSize(CGSizeMake(1000, height), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: subTitleLabel.font], context: nil).size
            
            subTitleLabel.frame = CGRectMake(0, y, expectedLabelSize.width, height)
        }
        
        if alwaysShowCoverArt || coverArtId != nil {
            coverArtView.hidden = false
            trackNumberLabel.hidden = true
            coverArtView.frame = CGRectMake(0, cellHeight - scrollViewHeight, scrollViewHeight, scrollViewHeight)
            scrollViewFrame.size.width -= scrollViewHeight
            scrollViewFrame.origin.x += scrollViewHeight
        } else {
            if trackNumber != nil {
                trackNumberLabel.hidden = playing
                nowPlayingImageView.hidden = !playing
                let width: CGFloat = 30.0
                trackNumberLabel.frame = CGRectMake(0, cellHeight - scrollViewHeight, width, scrollViewHeight)
                scrollViewFrame.size.width -= width
                scrollViewFrame.origin.x += width
                
                nowPlayingImageView.center = trackNumberLabel.center
            }
        }
        
        if duration != nil {
            durationLabel.hidden = false
            let width: CGFloat = 45.0
            durationLabel.frame = CGRectMake(cellWidth - width - (spacer * 3),
                                                   cellHeight - scrollViewHeight,
                                                   width,
                                                   scrollViewHeight)
            scrollViewFrame.size.width -= (width + (spacer * 3))
        }
        
        titlesScrollView.frame = scrollViewFrame
    }
}

extension ItemTableViewCell: DraggableCell {
    var draggable: Bool {
        get {
            return associatedObject is ISMSSong
        }
    }
    
    var dragItem: ISMSItem? {
        get {
            return associatedObject as? ISMSItem ?? nil
        }
    }
}
