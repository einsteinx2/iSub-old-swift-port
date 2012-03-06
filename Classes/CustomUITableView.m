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
#import "CellOverlay.h"
#import "SavedSettings.h"

#define ISMSHorizSwipeDragMin 3
#define ISMSVertSwipeDragMax 80

#define ISMSCellEnableDelay 1.0
#define ISMSTapAndHoldDelay 0.25

@implementation CustomUITableView

@synthesize lastDeleteToggle, lastOverlayToggle;

#pragma mark Lifecycle

- (void)setup
{
	lastDeleteToggle = [[NSDate date] retain];
	lastOverlayToggle = [[NSDate date] retain];
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

- (void)dealloc 
{
    [lastDeleteToggle release]; lastDeleteToggle = nil;
    [lastOverlayToggle release]; lastOverlayToggle = nil;
    [super dealloc];
}

#pragma mark Touch gestures interception

- (void)hideAllOverlays:(UITableViewCell *)cellToSkip
{
	// Remove any visible buttons
	for (UITableViewCell *cell in self.visibleCells) 
	{
		if (cell != cellToSkip)
			[cell hideOverlay];
	}
}

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{	
	// Don't try anything when the tableview is moving
	// and do not catch as a swipe if touch is far right (potential index control)
	if (!self.decelerating && point.x < 290)
	{
		// Find the cell
		UITableViewCell *cell = [self cellForRowAtIndexPath:[self indexPathForRowAtPoint:point]];
		
		// Handle multi delete touching
		if (self.editing &&
			point.x < 40. && [[NSDate date] timeIntervalSinceDate:lastDeleteToggle] > 0.25)
		{
			self.lastDeleteToggle = [NSDate date];
			[cell toggleDelete];
		}
		
		// Remove overlays
		if ([[NSDate date] timeIntervalSinceDate:lastOverlayToggle] > 0.5) 
		{
			self.lastOverlayToggle = [NSDate date];
			
			[self hideAllOverlays:cell];
			if ([cell isOverlayShowing])
				[cell performSelector:@selector(hideOverlay) withObject:nil afterDelay:1.0];
		}
	}
	//return nil;
	return [super hitTest:point withEvent:event];
}

- (BOOL)touchesShouldCancelInContentView:(UIView *)view 
{
	return YES;
}

- (BOOL)touchesShouldBegin:(NSSet *)touches withEvent:(UIEvent *)event inContentView:(UIView *)view 
{
	return YES;
}

#pragma mark Touch gestures for custom cell view

- (void)disableCellsTemporarily
{
	self.allowsSelection = NO;
	[self performSelector:@selector(enableCells) withObject:nil afterDelay:ISMSCellEnableDelay];
}

- (void)enableCells
{
	self.allowsSelection = YES;
}

- (BOOL)isTouchHorizontal:(UITouch *)touch 
{
    CGPoint currentTouchPosition = [touch locationInView:self];
	if (fabsf(startTouchPosition.x - currentTouchPosition.x) >= 1.0) 
		return YES;
	
	return NO;
}

- (BOOL)isTouchVertical:(UITouch *)touch
{
	CGPoint currentTouchPosition = [touch locationInView:self];
	if (fabsf(startTouchPosition.y - currentTouchPosition.y) >= 2.0) 
		return YES;
	
	return NO;
}

- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event 
{
    CGPoint currentTouchPosition = [[touches anyObject] locationInView:self];
	UITableViewCell *cell = [self cellForRowAtIndexPath: [self indexPathForRowAtPoint:currentTouchPosition]];
	
	if (!hasSwiped) 
	{
		// Check if this is a full swipe
		if (fabsf(startTouchPosition.x - currentTouchPosition.x) >= ISMSHorizSwipeDragMin 
			&& fabsf(startTouchPosition.y - currentTouchPosition.y) <= ISMSVertSwipeDragMax)
		{
			hasSwiped = YES;
			self.scrollEnabled = NO;			
			
			// Temporarily disable the cells so we don't get accidental selections
			[self disableCellsTemporarily];
			
			// Hide any open overlays
			[self hideAllOverlays:nil];
			
			// Detect the direction
			if (startTouchPosition.x < currentTouchPosition.x) 
			{
				// Right swipe
				if (settingsS.isSwipeEnabled && !IS_IPAD())
				{
					[cell showOverlay];
					cellShowingOverlay = cell;
				}
			} 
			else 
			{
				// Left Swipe				
				[cell scrollLabels];
			}
		} 
		else 
		{
			// Process a non-swipe event.
		}
	}
}

- (void)tapAndHoldFired
{
    tapAndHoldFired = YES;
	[tapAndHoldCell showOverlay];
	cellShowingOverlay = tapAndHoldCell;
}

- (void)cancelTapAndHold
{
    [NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(tapAndHoldFired) object:nil];
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{	
	self.allowsSelection = NO;
	self.scrollEnabled = YES;
		
	// Handle swipe
    startTouchPosition = [[touches anyObject] locationInView:self];
	hasSwiped = NO;
	cellShowingOverlay = nil;

	// Handle tap and hold
	if (settingsS.isTapAndHoldEnabled)
	{
		tapAndHoldFired = NO;
		tapAndHoldCell = [self cellForRowAtIndexPath: [self indexPathForRowAtPoint:startTouchPosition]];
		[self performSelector:@selector(tapAndHoldFired) withObject:nil afterDelay:ISMSTapAndHoldDelay];
	}
	
	[super touchesBegan:touches withEvent:event];
}

- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event 
{	
	// Cancel the tap and hold if user moves finger
	[self cancelTapAndHold];
	
	// Check for swipe
	if ([self isTouchHorizontal:[touches anyObject]]) 
	{
		[self lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event];
	} 
	
	[super touchesMoved:touches withEvent:event];
}

- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	self.allowsSelection = YES;
	self.scrollEnabled = YES;
	
	[self cancelTapAndHold];

	if (tapAndHoldFired || hasSwiped)
	{
		// Enable the buttons if the overlay is showing
		[[cellShowingOverlay overlayView] enableButtons];
	}
	else
	{
		// Select the cell if this was a touch not a swipe or tap and hold
		CGPoint currentTouchPosition = [[touches anyObject] locationInView:self];
		if ((self.editing && currentTouchPosition.x > 40.) || !self.editing)
		{
			UITableViewCell *cell = [self cellForRowAtIndexPath: [self indexPathForRowAtPoint:currentTouchPosition]];
			[self selectRowAtIndexPath:[self indexPathForCell:cell] animated:NO scrollPosition:UITableViewScrollPositionNone];
			[self.delegate tableView:self didSelectRowAtIndexPath:[self indexPathForCell:cell]];
		}
	}
	hasSwiped = NO;
	
	[super touchesEnded:touches withEvent:event];
}

- (void)touchesCancelled:(NSSet *)touches withEvent:(UIEvent *)event
{
    [self cancelTapAndHold];
	
	self.allowsSelection = YES;
	self.scrollEnabled = YES;
	hasSwiped = NO;
	
	[[cellShowingOverlay overlayView] enableButtons];
	
	[super touchesCancelled:touches withEvent:event];
}


@end
