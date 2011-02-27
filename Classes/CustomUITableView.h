//
//  CustomUITableView.h
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface CustomUITableView : UITableView 
{
	BOOL blockInput;
	
	NSDate *lastDeleteToggle;
	NSDate *lastOverlayToggle;
}

@property BOOL blockInput;
@property (nonatomic, retain) NSDate *lastDeleteToggle;
@property (nonatomic, retain) NSDate *lastOverlayToggle;

@end
