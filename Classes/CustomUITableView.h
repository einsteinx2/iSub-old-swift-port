//
//  CustomUITableView.h
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface CustomUITableView : UITableView 
{	
	CGPoint startTouchPosition;
	BOOL hasSwiped;
	UITableViewCell *cellShowingOverlay;
	UITableViewCell *tapAndHoldCell;
}

@property (retain) NSDate *lastDeleteToggle;

- (BOOL)isTouchHorizontal:(UITouch *)touch;
- (BOOL)isTouchVertical:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;

- (void)disableCellsTemporarily;
- (void)enableCells;

@end
