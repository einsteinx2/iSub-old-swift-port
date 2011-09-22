//
//  PlayingUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class AsynchronousImageViewCached, iSubAppDelegate, ViewObjectsSingleton;

@interface BookmarkUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	
	NSIndexPath *indexPath;
	
	UIImageView *deleteToggleImage;
	BOOL isDelete;
	
	AsynchronousImageViewCached *coverArtView;
	UILabel *bookmarkNameLabel;
	UIScrollView *nameScrollView;
	CGFloat scrollWidth;
	UILabel *songNameLabel;
	UILabel *artistNameLabel;
	
	CGPoint startTouchPosition;
	BOOL swiping;
	BOOL hasSwiped;
	BOOL fingerIsMovingLeftOrRight;
	BOOL fingerMovingVertically;
}

@property (nonatomic, retain) AsynchronousImageViewCached *coverArtView;
@property (nonatomic, retain) UILabel *bookmarkNameLabel;
@property (nonatomic, retain) UIScrollView *nameScrollView;
@property (nonatomic, retain) UILabel *songNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;

@property (nonatomic, retain) NSIndexPath *indexPath;

@property (nonatomic, retain) UIImageView *deleteToggleImage;
@property BOOL isDelete;

- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;
- (void)isOverlayShowing;

- (void)toggleDelete;

@end
