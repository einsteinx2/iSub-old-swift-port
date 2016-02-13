//
//  ChatUITableViewCell.swift
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

import Foundation
import UIKit

public class ChatUITableViewCell : UITableViewCell {
    
    public let userNameLabel: UILabel = UILabel()
    public let messageLabel: UILabel = UILabel()
    
    // MARK: - Lifecycle -
    
    required public init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    override init(style: UITableViewCellStyle, reuseIdentifier: String?) {
        self.userNameLabel.frame = CGRectMake(0, 0, 320, 20)
        self.userNameLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth;
        self.userNameLabel.textAlignment = NSTextAlignment.Center;
        self.userNameLabel.backgroundColor = UIColor.blackColor()
        self.userNameLabel.alpha = 0.65
        self.userNameLabel.font = ISMSBoldFont(10)
        self.userNameLabel.textColor = UIColor.whiteColor()
        
        self.messageLabel.frame = CGRectMake(5, 20, 310, 55)
        self.messageLabel.autoresizingMask = UIViewAutoresizing.FlexibleWidth;
        self.messageLabel.textAlignment = NSTextAlignment.Left;
        self.messageLabel.backgroundColor = UIColor.clearColor()
        self.messageLabel.font = ISMSRegularFont(20)
        self.messageLabel.lineBreakMode = NSLineBreakMode.ByWordWrapping
        self.messageLabel.numberOfLines = 0
        
        super.init(style: style, reuseIdentifier: reuseIdentifier)
        
        self.contentView.addSubview(self.userNameLabel)
        self.contentView.addSubview(self.messageLabel)
    }
    
    public override func layoutSubviews() {
        super.layoutSubviews()
        
        // Automatically set the height based on the height of the message text
        if let text = self.messageLabel.text {
            var expectedLabelSize: CGSize = text.boundingRectWithSize(CGSizeMake(310, CGFloat.max), options: NSStringDrawingOptions.UsesLineFragmentOrigin, attributes: [NSFontAttributeName: self.messageLabel.font], context: nil).size
            
            if expectedLabelSize.height < 40 {
                expectedLabelSize.height = 40
            }
            
            var newFrame: CGRect = self.messageLabel.frame
            newFrame.size.height = expectedLabelSize.height
            self.messageLabel.frame = newFrame
        }
    }

    // MARK: - Overlay -
    
    public func hideOverlay() {
        
    }
    
    public func showOverlay() {
    	
    }
}
