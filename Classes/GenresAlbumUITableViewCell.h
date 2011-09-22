//
//  AlbumUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, AsynchronousImageViewCached, MusicSingleton, DatabaseSingleton;

@interface GenresAlbumUITableViewCell : UITableViewCell 
{
	NSInteger segment;
	NSString *seg1;
	NSString *genre;
	
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	AsynchronousImageViewCached *coverArtView;
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
@property (nonatomic, retain) NSString *genre;

@property (nonatomic, retain) AsynchronousImageViewCached *coverArtView;
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
