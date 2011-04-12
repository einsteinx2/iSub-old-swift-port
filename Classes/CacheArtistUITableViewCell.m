//
//  ArtistUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 5/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheArtistUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "FMDatabase.h"
#import "CellOverlay.h"

@implementation CacheArtistUITableViewCell

@synthesize indexPath, artistNameScrollView, artistNameLabel, isOverlayShowing, overlayView, isIndexShowing;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
	if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		// Initialization code
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		
		isOverlayShowing = NO;
		
		artistNameScrollView = [[UIScrollView alloc] init];
		artistNameScrollView.frame = CGRectMake(5, 0, 320, 44);
		artistNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		artistNameScrollView.showsVerticalScrollIndicator = NO;
		artistNameScrollView.showsHorizontalScrollIndicator = NO;
		artistNameScrollView.userInteractionEnabled = NO;
		artistNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:artistNameScrollView];
		[artistNameScrollView release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[artistNameScrollView addSubview:artistNameLabel];
		[artistNameLabel release];
	}
	
	return self;
}


// Empty function
- (void)toggleDelete
{
}


- (void)deleteAction
{
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(deleteAllSongs) withObject:nil];
	
	overlayView.downloadButton.alpha = .3;
	overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}


- (void)deleteAllSongs
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	FMResultSet *result;
	result = [databaseControls.songCacheDb executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ?", artistNameLabel.text];
	
	while ([result next])
	{
		[databaseControls removeSongFromCacheDb:[result stringForColumnIndex:0]];
	}
	
	// Reload the cached songs table
	[[NSNotificationCenter defaultCenter] postNotificationName:@"cachedSongDeleted" object:nil];
	
	// Hide the loading screen	
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	
	[autoreleasePool release];
}

- (void)queueAction
{
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(queueAllSongs) withObject:nil];
	[self hideOverlay];
}


- (void)blockerAction
{
	//NSLog(@"blockerAction");
	[self hideOverlay];
}


- (void)hideOverlay
{
	if (overlayView)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
			overlayView.alpha = 0.0;
		[UIView commitAnimations];
		
		isOverlayShowing = NO;
	}
}


- (void)showOverlay
{
	if (!isOverlayShowing)
	{
		overlayView = [CellOverlay cellOverlayWithTableCell:self];
		[self.contentView addSubview:overlayView];
		
		[overlayView.downloadButton setImage:viewObjects.deleteButtonImage forState:UIControlStateNormal];
		[overlayView.downloadButton addTarget:self action:@selector(deleteAction) forControlEvents:UIControlEventTouchUpInside];
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
		overlayView.alpha = 1.0;
		[UIView commitAnimations];		
		
		isOverlayShowing = YES;
	}
}


- (void)queueAllSongs
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	FMResultSet *result;
	
	result = [databaseControls.songCacheDb executeQuery:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? ORDER BY seg2 COLLATE NOCASE", artistNameLabel.text];
	
	while ([result next])
	{
		[databaseControls addSongToPlaylistQueue:[databaseControls songFromCacheDb:[result stringForColumnIndex:0]]];
	}
	
	[result close];
	
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
		
	[autoreleasePool release];
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)layoutSubviews 
{	
    [super layoutSubviews];
	
	/*NSUInteger width;
	if (isIndexShowing)
		width = 260;
	else
		width = 290;
	
	self.contentView.frame = CGRectMake(0, 0, 320, 44);*/
	
	// Automatically set the width based on the width of the text
	artistNameLabel.frame = CGRectMake(0, 0, 290, 44);
	CGSize expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,44) lineBreakMode:artistNameLabel.lineBreakMode]; 
	CGRect newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	artistNameLabel.frame = newFrame;
}


#pragma mark Touch gestures for custom cell view

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
	UITouch *touch = [touches anyObject];
    startTouchPosition = [touch locationInView:self];
	swiping = NO;
	hasSwiped = NO;
	fingerIsMovingLeftOrRight = NO;
	fingerMovingVertically = NO;
	[self.nextResponder touchesBegan:touches withEvent:event];
}


- (void)touchesMoved:(NSSet *)touches withEvent:(UIEvent *)event 
{
	if ([self isTouchGoingLeftOrRight:[touches anyObject]]) 
	{
		[self lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event];
		[super touchesMoved:touches withEvent:event];
	} 
	else 
	{
		[self.nextResponder touchesMoved:touches withEvent:event];
	}
}


// Determine what kind of gesture the finger event is generating
- (BOOL)isTouchGoingLeftOrRight:(UITouch *)touch 
{
    CGPoint currentTouchPosition = [touch locationInView:self];
	if (fabsf(startTouchPosition.x - currentTouchPosition.x) >= 1.0) 
	{
		fingerIsMovingLeftOrRight = YES;
		return YES;
    } 
	else 
	{
		fingerIsMovingLeftOrRight = NO;
		return NO;
	}
	
	if (fabsf(startTouchPosition.y - currentTouchPosition.y) >= 2.0) 
	{
		fingerMovingVertically = YES;
	} 
	else 
	{
		fingerMovingVertically = NO;
	}
}


- (BOOL)fingerIsMoving {
	return fingerIsMovingLeftOrRight;
}

- (BOOL)fingerIsMovingVertically {
	return fingerMovingVertically;
}

// Check for swipe gestures
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event {
    UITouch *touch = [touches anyObject];
    CGPoint currentTouchPosition = [touch locationInView:self];
	
	[self setSelected:NO];
	swiping = YES;
	
	//ShoppingAppDelegate *appDelegate = (ShoppingAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	if (hasSwiped == NO) 
	{
		// If the swipe tracks correctly.
		if (fabsf(startTouchPosition.x - currentTouchPosition.x) >= viewObjects.kHorizSwipeDragMin &&
			fabsf(startTouchPosition.y - currentTouchPosition.y) <= viewObjects.kVertSwipeDragMax)
		{
			// It appears to be a swipe.
			if (startTouchPosition.x < currentTouchPosition.x) 
			{
				// Right swipe
				// Disable the cells so we don't get accidental selections
				viewObjects.isCellEnabled = NO;
				
				hasSwiped = YES;
				swiping = NO;
				
				[self showOverlay];
				
				// Re-enable cell touches in 1 second
				viewObjects.cellEnabledTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:viewObjects selector:@selector(enableCells) userInfo:nil repeats:NO];
			} 
			else 
			{
				// Left Swipe
				// Disable the cells so we don't get accidental selections
				viewObjects.isCellEnabled = NO;
				
				hasSwiped = YES;
				swiping = NO;
				
				if (artistNameLabel.frame.size.width > artistNameScrollView.frame.size.width)
				{
					[artistNameScrollView setContentOffset:CGPointMake(artistNameLabel.frame.size.width - artistNameScrollView.frame.size.width, 0) animated:YES];
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:artistNameLabel.frame.size.width/(float)150];
					artistNameScrollView.contentOffset = CGPointMake(artistNameLabel.frame.size.width - artistNameScrollView.frame.size.width, 0);
					[UIView commitAnimations];
				}
				
				// Re-enable cell touches in 1 second
				viewObjects.cellEnabledTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:viewObjects selector:@selector(enableCells) userInfo:nil repeats:NO];
			}
		} 
		else 
		{
			// Process a non-swipe event.
		}
		
	}
}


- (void)textScrollingStopped
{
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:artistNameLabel.frame.size.width/(float)150];
	artistNameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}


- (void)touchesEnded:(NSSet *)touches withEvent:(UIEvent *)event 
{
	swiping = NO;
	hasSwiped = NO;
	fingerMovingVertically = NO;
	[self.nextResponder touchesEnded:touches withEvent:event];
}



- (void)dealloc {
	[indexPath release];
    [super dealloc];
}


@end
