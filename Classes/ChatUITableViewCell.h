//
//  ChatUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableViewCell.h"

@interface ChatUITableViewCell : CustomUITableViewCell 
{
	UILabel *userNameLabel;
	UILabel *messageLabel;
}

@property (nonatomic, retain) UILabel *userNameLabel;
@property (nonatomic, retain) UILabel *messageLabel;

@end
