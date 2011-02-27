//
//  AllAlbumsUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, DatabaseControlsSingleton, MusicControlsSingleton, AsynchronousImageViewCached, Artist;

@interface AllAlbumsUITableViewCell : UITableViewCell 
{
	NSString *myId;
	Artist *myArtist;
	
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	DatabaseControlsSingleton *databaseControls;
	MusicControlsSingleton *musicControls;
	
	AsynchronousImageViewCached *coverArtView;
	CGFloat scrollWidth;
	UIScrollView *albumNameScrollView;
	UILabel *albumNameLabel;
	UILabel *artistNameLabel;
	
	BOOL canShowOverlay;
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
		
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
@property (nonatomic, retain) UILabel *artistNameLabel;

@property BOOL canShowOverlay;
@property BOOL isOverlayShowing;
@property (nonatomic, retain) CellOverlay *overlayView;


- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;

// Empty function
- (void)toggleDelete;

@end
