//
//  AllAlbumsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, AsynchronousImageViewCached, MusicSingleton, DatabaseSingleton;

@interface AllSongsUITableViewCell : UITableViewCell 
{
	NSIndexPath *indexPath;
	NSString *md5;
	
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	AsynchronousImageViewCached *coverArtView;
	UIScrollView *songNameScrollView;
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
@property (nonatomic, retain) NSString *md5;

@property (nonatomic, retain) AsynchronousImageViewCached *coverArtView;
@property (nonatomic, retain) UIScrollView *songNameScrollView;
@property (nonatomic, retain) UILabel *songNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;

@property BOOL isOverlayShowing;
@property (nonatomic, retain) CellOverlay *overlayView;


- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;

// Empty function
- (void)toggleDelete;

@end
