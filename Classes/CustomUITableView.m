//
//  CustomUITableView.m
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableView.h"
#import "ViewObjectsSingleton.h"
//#import "UITableViewCell-overlay.h"

@interface NSObject (cell)
- (void)toggleDelete;
- (BOOL)fingerIsMovingVertically;
- (void)hideOverlay;
- (BOOL)isOverlayShowing;
- (UIView *)contentView;
@end


@implementation CustomUITableView

@synthesize blockInput, lastDeleteToggle, lastOverlayToggle;

- (id)initWithFrame:(CGRect)frame 
{
    if ((self = [super initWithFrame:frame])) 
	{		
		self.lastDeleteToggle = [NSDate date];
		self.lastOverlayToggle = [NSDate date];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		self.lastDeleteToggle = [NSDate date];
		self.lastOverlayToggle = [NSDate date];
	}
	return self;
}

#pragma mark Touch gestures interception

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	if (!blockInput)
	{
		ViewObjectsSingleton *viewObjects = [ViewObjectsSingleton sharedInstance];
		
		if (self.decelerating)
		{
			// don't try anything when the tableview is moving..
			return [super hitTest:point withEvent:event];
		}
		
		// Do not catch as a swipe if touch is far right (potential index control)
		if (point.x > 290) 
		{
			return [super hitTest:point withEvent:event];
		}
		
		// Handle multi delete touching
		if (viewObjects.isEditing)
		{
			//DLog(@"inside the isEditing IF");
			if ((point.x < 40) && ([[NSDate date] timeIntervalSinceDate:lastDeleteToggle] > 0.25))
			{
				self.lastDeleteToggle = [NSDate date];
				NSIndexPath *indexPathAtHitPoint = [self indexPathForRowAtPoint:point];
				id cell = [self cellForRowAtIndexPath:indexPathAtHitPoint];
				[cell toggleDelete];
				//return (UIView *)[cell contentView];
			}
		}
		
		// Find the cell
		NSIndexPath *indexPathAtHitPoint = [self indexPathForRowAtPoint:point];
		id cell = [self cellForRowAtIndexPath:indexPathAtHitPoint];
		// forward to the cell unless we desire to have vertical scrolling
		if (cell != nil && [cell fingerIsMovingVertically] == NO && [[NSDate date] timeIntervalSinceDate:lastOverlayToggle] > 0.5) 
		{
			self.lastOverlayToggle = [NSDate date];
			
			// Remove any visible buttons
			for (id cell2 in self.visibleCells) 
			{
				if (cell2 != cell)
					[cell2 hideOverlay];
			}
			
			if ([cell isOverlayShowing])
			{
				[NSTimer scheduledTimerWithTimeInterval:1 target:cell selector:@selector(hideOverlay) userInfo:nil repeats:NO];
				return [super hitTest:point withEvent:event];
			}
			else
			{
				return (UIView *)[cell contentView];
			}
		}
	}
	
	return [super hitTest:point withEvent:event];
}



- (BOOL)touchesShouldCancelInContentView:(UIView *)view 
{
	return YES;
}


- (BOOL)touchesShouldBegin:(NSSet *)touches withEvent:(UIEvent *)event inContentView:(UIView *)view 
{
	return !blockInput;
}

- (void)dealloc 
{
    [lastDeleteToggle release]; lastDeleteToggle = nil;
    [lastOverlayToggle release]; lastOverlayToggle = nil;
    [super dealloc];
}


@end
