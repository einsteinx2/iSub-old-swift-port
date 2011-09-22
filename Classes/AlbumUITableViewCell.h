//
//  AlbumUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class CellOverlay, AsynchronousImageViewCached, iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, Artist;

@interface AlbumUITableViewCell : UITableViewCell 
{
	NSString *myId;
	
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	AsynchronousImageViewCached *coverArtView;
	UIScrollView *albumNameScrollView;
	UILabel *albumNameLabel;
	
	Artist *myArtist;
	
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
	
	BOOL isIndexShowing;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
}

@property (nonatomic, retain) NSString *myId;
@property (nonatomic, retain) Artist *myArtist;

@property (nonatomic, retain) AsynchronousImageViewCached *coverArtView;
@property (nonatomic, retain) UIScrollView *albumNameScrollView;
@property (nonatomic, retain) UILabel *albumNameLabel;

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
