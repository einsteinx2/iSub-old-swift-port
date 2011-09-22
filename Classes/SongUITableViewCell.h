//
//  SongUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class CellOverlay, iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, Song, CellOverlay;

@interface SongUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	NSIndexPath *indexPath;
	Song *mySong;
	
	UILabel *trackNumberLabel;
	CGFloat scrollWidth;
	UIScrollView *songNameScrollView;
	UILabel *songNameLabel;
	UILabel *artistNameLabel;
	UILabel *songDurationLabel;
	
	BOOL isOverlayShowing;
	CellOverlay *overlayView;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
}

@property (nonatomic, retain) NSIndexPath *indexPath;
@property (nonatomic, retain) Song *mySong;

@property (nonatomic, retain) UILabel *trackNumberLabel;
@property (nonatomic, retain) UIScrollView *songNameScrollView;
@property (nonatomic, retain) UILabel *songNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;
@property (nonatomic, retain) UILabel *songDurationLabel;

@property BOOL isOverlayShowing;
@property (nonatomic, retain) CellOverlay *overlayView;


- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;

// Empty function
- (void)toggleDelete;

@end
