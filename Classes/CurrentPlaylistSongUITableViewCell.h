//
//  PlaylistSongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, AsynchronousImageViewCached, MusicSingleton, DatabaseSingleton;

@interface CurrentPlaylistSongUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	NSIndexPath *indexPath;
	
	UIImageView *deleteToggleImage;
	BOOL isDelete;
	
	AsynchronousImageViewCached *coverArtView;
	UILabel *numberLabel;
	UIScrollView *nameScrollView;
	CGFloat scrollWidth;
	UILabel *songNameLabel;
	UILabel *artistNameLabel;
	
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
}

@property (nonatomic, retain) NSIndexPath *indexPath;

@property (nonatomic, retain) UIImageView *deleteToggleImage;
@property BOOL isDelete;

@property (nonatomic, retain) AsynchronousImageViewCached *coverArtView;
@property (nonatomic, retain) UILabel *numberLabel;
@property (nonatomic, retain) UIScrollView *nameScrollView;
@property (nonatomic, retain) UILabel *songNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;

@property BOOL isOverlayShowing;
@property (nonatomic, retain) CellOverlay *overlayView;

- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;

- (void)toggleDelete;

@end
