//
//  PlayingUITableViewCell.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, AsynchronousImageViewCached;

@interface PlayingUITableViewCell : UITableViewCell 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	
	AsynchronousImageViewCached *coverArtView;
	UILabel *userNameLabel;
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
@property (nonatomic, retain) UILabel *userNameLabel;
@property (nonatomic, retain) UIScrollView *nameScrollView;
@property (nonatomic, retain) UILabel *songNameLabel;
@property (nonatomic, retain) UILabel *artistNameLabel;

- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch;
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event;
- (void)hideOverlay;
- (void)showOverlay;
- (void)isOverlayShowing;

@end
