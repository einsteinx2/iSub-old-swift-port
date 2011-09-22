//
//  ArtistUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, DatabaseSingleton;

@interface CacheArtistUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	DatabaseSingleton *databaseControls;
	
	NSIndexPath *indexPath;
	
	UIScrollView *artistNameScrollView;
	UILabel *artistNameLabel;
	
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
	BOOL isIndexShowing;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
}

@property (nonatomic, retain) NSIndexPath *indexPath;

@property (nonatomic, retain) UIScrollView *artistNameScrollView;
@property (nonatomic, retain) UILabel *artistNameLabel;

@property BOOL isOverlayShowing;
@property (nonatomic, retain) CellOverlay *overlayView;
@property BOOL isIndexShowing;

- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;

// Empty function
- (void)toggleDelete;

@end
