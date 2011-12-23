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
	BOOL swiping;
	BOOL hasSwiped;
	BOOL isFingerMovingLeftOrRight;
	BOOL isFingerMovingVertically;
}

@property (nonatomic) BOOL blockInput;
@property (nonatomic, retain) NSDate *lastDeleteToggle;
@property (nonatomic, retain) NSDate *lastOverlayToggle;

@property (nonatomic) BOOL isCellsEnabled;

- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;

@end
