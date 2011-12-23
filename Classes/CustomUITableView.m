//
//  CustomUITableView.m
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITableView.h"
#import "ViewObjectsSingleton.h"
#import "UITableViewCell+overlay.h"

#define ISMSHorizSwipeDragMin 3
#define ISMSVertSwipeDragMax 80

@implementation CustomUITableView

@synthesize blockInput, lastDeleteToggle, lastOverlayToggle, isCellsEnabled;

- (void)setup
{
	self.lastDeleteToggle = [NSDate date];
	self.lastOverlayToggle = [NSDate date];
	isCellsEnabled = YES;
}

- (id)initWithFrame:(CGRect)frame 
{
    if ((self = [super initWithFrame:frame])) 
	{		
		[self setup];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		[self setup];
	}
	return self;
}

- (void)hideAllOverlays:(UITableViewCell *)cellToSkip
{
	// Remove any visible buttons
	for (UITableViewCell *cell in self.visibleCells) 
	{
		if (cell != cellToSkip)
			[cell hideOverlay];
	}
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
				UITableViewCell *cell = [self cellForRowAtIndexPath:indexPathAtHitPoint];
				[cell toggleDelete];
				//return (UIView *)[cell contentView];
			}
		}
		
		// Find the cell
		NSIndexPath *indexPathAtHitPoint = [self indexPathForRowAtPoint:point];
		UITableViewCell *cell = [self cellForRowAtIndexPath:indexPathAtHitPoint];
		// forward to the cell unless we desire to have vertical scrolling
		//if (cell != nil && [cell fingerIsMovingVertically] == NO && [[NSDate date] timeIntervalSinceDate:lastOverlayToggle] > 0.5) 
		if (cell != nil && !isFingerMovingVertically && [[NSDate date] timeIntervalSinceDate:lastOverlayToggle] > 0.5) 
		{
			self.lastOverlayToggle = [NSDate date];
			
			[self hideAllOverlays:cell];
			
			if ([cell isOverlayShowing])
			{
				[NSTimer scheduledTimerWithTimeInterval:1 target:cell selector:@selector(hideOverlay) userInfo:nil repeats:NO];
				return [super hitTest:point withEvent:event];
			}
			else
			{
				return [super hitTest:point withEvent:event];
				//return (UIView *)[cell contentView];
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


#pragma mark Touch gestures for custom cell view

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
	UITouch *touch = [touches anyObject];
    startTouchPosition = [touch locationInView:self];
	swiping = NO;
	hasSwiped = NO;
	isFingerMovingLeftOrRight = NO;
	isFingerMovingVertically = NO;
	[super touchesBegan:touches withEvent:event];
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event 
{
	if ([self isTouchGoingLeftOrRight:[touches anyObject]]) 
	{
		[self lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event];
	} 
	
	[super touchesMoved:touches withEvent:event];
}


// Determine what kind of gesture the finger event is generating
- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch 
{
    CGPoint currentTouchPosition = [touch locationInView:self];
	if (fabsf(startTouchPosition.x - currentTouchPosition.x) >= 1.0) 
	{
		isFingerMovingLeftOrRight = YES;
		return YES;
    } 
	else 
	{
		isFingerMovingLeftOrRight = NO;
		return NO;
	}
	
	if (fabsf(startTouchPosition.y - currentTouchPosition.y) >= 2.0) 
	{
		isFingerMovingVertically = YES;
	} 
	else 
	{
		isFingerMovingVertically = NO;
	}
}

- (void)enableCells
{
	isCellsEnabled = YES;
}

// Check for swipe gestures
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event 
{
    UITouch *touch = [touches anyObject];
    CGPoint currentTouchPosition = [touch locationInView:self];
	
	NSIndexPath *indexPathAtHitPoint = [self indexPathForRowAtPoint:currentTouchPosition];
	UITableViewCell *cell = [self cellForRowAtIndexPath:indexPathAtHitPoint];
	
	cell.selected = NO;
	swiping = YES;
		
	if (hasSwiped == NO) 
	{
		// If the swipe tracks correctly.
		if (fabsf(startTouchPosition.x - currentTouchPosition.x) >= ISMSHorizSwipeDragMin &&
			fabsf(startTouchPosition.y - currentTouchPosition.y) <= ISMSVertSwipeDragMax)
		{
			// It appears to be a swipe.
			if (startTouchPosition.x < currentTouchPosition.x) 
			{
				// Right swipe
				// Disable the cells so we don't get accidental selections
				isCellsEnabled = NO;
				
				hasSwiped = YES;
				swiping = NO;
				
				[cell showOverlay];
				
				// Re-enable cell touches in 1 second
				[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(enableCells) userInfo:nil repeats:NO];
			} 
			else 
			{
				// Left Swipe
				// Disable the cells so we don't get accidental selections
				isCellsEnabled = NO;
				
				hasSwiped = YES;
				swiping = NO;
				
				[cell scrollLabels];
				
				/*if (albumNameLabel.frame.size.width > albumNameScrollView.frame.size.width)
				{
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:albumNameLabel.frame.size.width/(float)150];
					albumNameScrollView.contentOffset = CGPointMake(albumNameLabel.frame.size.width - albumNameScrollView.frame.size.width + 10, 0);
					[UIView commitAnimations];
				}*/
				
				// Re-enable cell touches in 1 second
				[NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(enableCells) userInfo:nil repeats:NO];
			}
		} 
		else 
		{
			// Process a non-swipe event.
		}
	}
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	swiping = NO;
	hasSwiped = NO;
	isFingerMovingVertically = NO;
	[super touchesEnded:touches withEvent:event];
}



@end
