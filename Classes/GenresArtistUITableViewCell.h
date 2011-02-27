//
//  ArtistUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton;

@interface GenresArtistUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	NSString *genre;
	
	UIScrollView *artistNameScrollView;
	UILabel *artistNameLabel;
	
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
}

@property (nonatomic, retain) NSString *genre;

@property (nonatomic, retain) UIScrollView *artistNameScrollView;
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
