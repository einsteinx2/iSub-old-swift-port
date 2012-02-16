//
//  CellOverlay.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@interface CellOverlay : UIView 
{
	UIButton *inputBlocker;
	UIButton *downloadButton;
	UIButton *queueButton;
}
@property (retain) UIButton *inputBlocker;
@property (retain) UIButton *downloadButton;
@property (retain) UIButton *queueButton;

+ (CellOverlay*)cellOverlayWithTableCell:(UITableViewCell*)cell;
- (id)initWithTableCell:(UITableViewCell*)cell;

- (void)enableButtons;

@end
