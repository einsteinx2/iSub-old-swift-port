//
//  PlaylistsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton;

@interface PlaylistsUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	NSIndexPath *indexPath;
	
	UIScrollView *playlistNameScrollView;
	UILabel *playlistNameLabel;
	
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
	
	UIImageView *deleteToggleImage;
	BOOL isDelete;
}

@property (nonatomic, retain) NSIndexPath *indexPath;

@property (nonatomic, retain) UIScrollView *playlistNameScrollView;
@property (nonatomic, retain) UILabel *playlistNameLabel;

@property BOOL isOverlayShowing;
@property (nonatomic, retain) CellOverlay *overlayView;

@property (nonatomic, retain) UIImageView *deleteToggleImage;
@property BOOL isDelete;

@property (nonatomic, retain) NSMutableData *receivedData;


- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;

- (void)toggleDelete;



@end
