//
//  DroppableCell.swift
//  iSub
//
//  Created by Benjamin Baron on 5/19/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

import UIKit

class DroppableCell: UITableViewCell {
    
    let containerView = UIView()
    var cellHeight: CGFloat = 50.0
    
    override var backgroundColor: UIColor? {
        get {
            return containerView.backgroundColor
        }
        set {
            containerView.backgroundColor = newValue
        }
    }
    
    private func commonInit() {
        super.backgroundColor = .clearColor()
        
        containerView.backgroundColor = .whiteColor()
        containerView.autoresizingMask = [.FlexibleWidth, .FlexibleBottomMargin]
        self.contentView.addSubview(containerView)
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
        containerView.frame = CGRect(x: 0, y: 0, width: self.width, height: cellHeight)
    }
}