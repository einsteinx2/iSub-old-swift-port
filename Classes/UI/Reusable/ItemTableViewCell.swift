//
//  ItemTableViewCell.swift
//  iSub
//
//  Created by Benjamin Baron on 12/16/14.
//  Copyright (c) 2014 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

@objc protocol ItemTableViewCellDelegate {
    @objc optional func tableCellDeleteButtonPressed(_ cell: ItemTableViewCell)
    @objc optional func tableCellDeleteToggled(_ cell: ItemTableViewCell, markedForDelete: Bool)
}

class ItemTableViewCell: DroppableCell {
    
    var indexPath: IndexPath? {
        get {
            return self.tableView?.indexPath(for: self)
        }
    }
    
    // Disabled for now until optimized
    let shouldRepositionLabels = false
        
    weak var delegate: ItemTableViewCellDelegate?
    var associatedObject: AnyObject?
    
    var indexShowing = false
    
    var searching = false
    
    var alwaysShowCoverArt = false
    var alwaysShowSubtitle = false
    
    var coverArtId: String? {
        didSet {
            if let coverArtId = coverArtId {
                coverArtView.loadImage(coverArtId: coverArtId, size: .cell)
            } else {
                coverArtView.setDefaultImage(forSize: .cell)
            }
            
            if shouldRepositionLabels {
                repositionLabels()
            }
        }
    }

    var trackNumber: Int? {
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
    
    var duration: Int? {
        didSet {
            if let duration = duration {
                durationLabel.text = NSString.formatTime(Double(duration))
            }
            if shouldRepositionLabels {
                repositionLabels()
            }
        }
    }
    
    var isPlaying: Bool = false {
        didSet {
            if isPlaying != oldValue {
                repositionLabels()
            }
        }
    }
    
    fileprivate let coverArtView = CachedImageView()
    fileprivate let trackNumberLabel = UILabel()
    fileprivate let headerTitleLabel = UILabel()
    fileprivate let titlesScrollView = UIScrollView()
    fileprivate let titleLabel = UILabel()
    fileprivate let subTitleLabel = UILabel()
    fileprivate let durationLabel = UILabel()
    fileprivate let nowPlayingImageView = UIImageView(image: UIImage(named: "playing-cell-icon"))
    
    // MARK: - Lifecycle -
    
    fileprivate func commonInit() {
        containerView.addSubview(coverArtView)
        
        trackNumberLabel.backgroundColor = UIColor.clear
        trackNumberLabel.textAlignment = NSTextAlignment.center
        trackNumberLabel.font = UIFont.boldSystemFont(ofSize: 22)
        trackNumberLabel.adjustsFontSizeToFitWidth = true
        trackNumberLabel.minimumScaleFactor = 16.0 / trackNumberLabel.font.pointSize
        containerView.addSubview(trackNumberLabel)
        
        nowPlayingImageView.isHidden = true
        containerView.addSubview(nowPlayingImageView)
        
        headerTitleLabel.textAlignment = NSTextAlignment.center
        headerTitleLabel.backgroundColor = UIColor.black
        headerTitleLabel.alpha = 0.65
        headerTitleLabel.font = UIFont.boldSystemFont(ofSize: 10)
        headerTitleLabel.textColor = UIColor.white
        containerView.addSubview(headerTitleLabel)
        
        titlesScrollView.frame = CGRect(x: 35, y: 0, width: 235, height: 50)
        titlesScrollView.autoresizingMask = UIViewAutoresizing.flexibleWidth
        titlesScrollView.showsVerticalScrollIndicator = false
        titlesScrollView.showsHorizontalScrollIndicator = false
        titlesScrollView.isUserInteractionEnabled = false
        titlesScrollView.decelerationRate = UIScrollViewDecelerationRateFast
        containerView.addSubview(titlesScrollView)
        
        titleLabel.backgroundColor = UIColor.clear
        titleLabel.textAlignment = NSTextAlignment.left
        titleLabel.font = UIFont.systemFont(ofSize: 16)
        titlesScrollView.addSubview(titleLabel)
        
        subTitleLabel.backgroundColor = UIColor.clear
        subTitleLabel.textAlignment = NSTextAlignment.left
        subTitleLabel.font = UIFont.systemFont(ofSize: 13)
        subTitleLabel.textColor = UIColor(white: 0.4, alpha: 1.0)
        titlesScrollView.addSubview(subTitleLabel)
        
        durationLabel.autoresizingMask = UIViewAutoresizing.flexibleWidth
        durationLabel.backgroundColor = UIColor.clear
        durationLabel.textAlignment = NSTextAlignment.right
        durationLabel.font = UIFont.systemFont(ofSize: 16)
        durationLabel.adjustsFontSizeToFitWidth = true
        durationLabel.minimumScaleFactor = 12.0 / durationLabel.font.pointSize
        durationLabel.textColor = UIColor.gray
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
        repositionLabels()
    }
    
    // MARK: - Public -

    func scrollLabels() {
        let titleWidth = titleLabel.frame.size.width
        let subTitleWidth = subTitleLabel.frame.size.width
        let scrollViewWidth = titlesScrollView.frame.size.width
        
        let longestTitleWidth = titleWidth > subTitleWidth ? titleWidth : subTitleWidth
        
        if longestTitleWidth > scrollViewWidth {
            let duration: TimeInterval = TimeInterval(titleWidth) / 150.0
            
            UIView.animate(withDuration: duration, animations: {
                self.titlesScrollView.contentOffset = CGPoint(x: longestTitleWidth - scrollViewWidth + 10, y: 0)
            }, completion: { (finished: Bool) in
                UIView.animate(withDuration: duration, animations: {
                    self.titlesScrollView.contentOffset = CGPoint.zero
                })
            })
        }
    }
    
    // MARK: - Private -
    
    // Automatically hide and show labels based on whether we have data for them, then reposition the others to fit
    func repositionLabels() {
        
        let cellWidth: CGFloat = indexShowing ? self.frame.size.width - CGFloat(20) : self.frame.size.width
        let spacer: CGFloat = 2.0
        
        coverArtView.isHidden = true
        trackNumberLabel.isHidden = true
        headerTitleLabel.isHidden = true
        titleLabel.isHidden = true
        subTitleLabel.isHidden = true
        durationLabel.isHidden = true
        
        var scrollViewFrame = CGRect(x: (spacer * 3), y: 0, width: cellWidth - (spacer * 6), height: cellHeight)
        if self.accessoryType == UITableViewCellAccessoryType.disclosureIndicator {
            scrollViewFrame.size.width -= 27.0
        }
        
        if headerTitle != nil {
            headerTitleLabel.isHidden = false
            
            let height: CGFloat = 20.0
            headerTitleLabel.frame = CGRect(x: 0, y: 0, width: cellWidth, height: height)
            
            scrollViewFrame.size.height -= height
            scrollViewFrame.origin.y += height
        }
        
        let scrollViewHeight = scrollViewFrame.size.height
        
        if title != nil {
            titleLabel.isHidden = false
            
            let height = subTitle == nil ? scrollViewHeight : scrollViewHeight * 0.60
            let expectedLabelSize: CGSize = titleLabel.text!.boundingRect(with: CGSize(width: 1000, height: height), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSFontAttributeName: titleLabel.font], context: nil).size
            
            titleLabel.frame = CGRect(x: 0, y: 0, width: expectedLabelSize.width, height: height)
        }
        
        if alwaysShowSubtitle || subTitle != nil {
            subTitleLabel.isHidden = false
            
            let y = scrollViewHeight * 0.57
            let height = scrollViewHeight * 0.33
            let text = subTitleLabel.text == nil ? "" : subTitleLabel.text!
            let expectedLabelSize = text.boundingRect(with: CGSize(width: 1000, height: height), options: NSStringDrawingOptions.usesLineFragmentOrigin, attributes: [NSFontAttributeName: subTitleLabel.font], context: nil).size
            
            subTitleLabel.frame = CGRect(x: 0, y: y, width: expectedLabelSize.width, height: height)
        }
        
        nowPlayingImageView.isHidden = true
        if alwaysShowCoverArt || coverArtId != nil {
            coverArtView.isHidden = false
            trackNumberLabel.isHidden = true
            coverArtView.frame = CGRect(x: 0, y: cellHeight - scrollViewHeight, width: scrollViewHeight, height: scrollViewHeight)
            scrollViewFrame.size.width -= scrollViewHeight
            scrollViewFrame.origin.x += scrollViewHeight
        } else if isPlaying || trackNumber != nil {
            trackNumberLabel.isHidden = isPlaying
            nowPlayingImageView.isHidden = !isPlaying
            let width: CGFloat = 30.0
            trackNumberLabel.frame = CGRect(x: 0, y: cellHeight - scrollViewHeight, width: width, height: scrollViewHeight)
            scrollViewFrame.size.width -= width
            scrollViewFrame.origin.x += width
            
            nowPlayingImageView.center = trackNumberLabel.center
        }
        
        if duration != nil {
            durationLabel.isHidden = false
            let width: CGFloat = 45.0
            durationLabel.frame = CGRect(x: cellWidth - width - (spacer * 3),
                                                   y: cellHeight - scrollViewHeight,
                                                   width: width,
                                                   height: scrollViewHeight)
            scrollViewFrame.size.width -= (width + (spacer * 3))
        }
        
        titlesScrollView.frame = scrollViewFrame
    }
}

extension ItemTableViewCell: DraggableCell {
    var isDraggable: Bool {
        return associatedObject is Song
    }
    
    var dragItem: Item? {
        return associatedObject as? Item
    }
}
