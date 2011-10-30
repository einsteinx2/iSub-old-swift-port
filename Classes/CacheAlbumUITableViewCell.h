//
//  AlbumUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, DatabaseSingleton;

@interface CacheAlbumUITableViewCell : UITableViewCell 
{	
	NSInteger segment;
	NSString *seg1;
	
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	DatabaseSingleton *databaseControls;
	
	UIImageView *coverArtView;
	UIScrollView *albumNameScrollView;
	UILabel *albumNameLabel;
	
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
}

@property NSInteger segment;
@property (nonatomic, retain) NSString *seg1;

@property (nonatomic, retain) UIImageView *coverArtView;
@property (nonatomic, retain) UIScrollView *albumNameScrollView;
@property (nonatomic, retain) UILabel *albumNameLabel;

@property BOOL isOverlayShowing;
@property (nonatomic, retain) CellOverlay *overlayView;


- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;

// Empty function
- (void)toggleDelete;

@end
