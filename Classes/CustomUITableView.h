//
//  CustomUITableView.h
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class SavedSettings;
@interface CustomUITableView : UITableView 
{	
	CGPoint startTouchPosition;
	BOOL hasSwiped;
	UITableViewCell *cellShowingOverlay;
	BOOL tapAndHoldFired;
	UITableViewCell *tapAndHoldCell;
	
	SavedSettings *settings;
}

@property (nonatomic, retain) NSDate *lastDeleteToggle;
@property (nonatomic, retain) NSDate *lastOverlayToggle;

- (BOOL)isTouchHorizontal:(UITouch *)touch;
- (BOOL)isTouchVertical:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;

- (void)disableCellsTemporarily;
- (void)enableCells;

@end
