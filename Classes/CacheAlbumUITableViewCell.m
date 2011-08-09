//
//  AlbumUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheAlbumUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "FMDatabase.h"
#import "CellOverlay.h"

@implementation CacheAlbumUITableViewCell

@synthesize segment, seg1, coverArtView, albumNameScrollView, albumNameLabel, isOverlayShowing, overlayView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		// Initialization code
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance]; 
		
		isOverlayShowing = NO;
		
		coverArtView = [[UIImageView alloc] init];
		[self.contentView addSubview:coverArtView];
		[coverArtView release];
		
		albumNameScrollView = [[UIScrollView alloc] init];
		albumNameScrollView.frame = CGRectMake(65, 0, 250, 60);
		albumNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		albumNameScrollView.showsVerticalScrollIndicator = NO;
		albumNameScrollView.showsHorizontalScrollIndicator = NO;
		albumNameScrollView.userInteractionEnabled = NO;
		albumNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:albumNameScrollView];
		[albumNameScrollView release];
		
		albumNameLabel = [[UILabel alloc] init];
		albumNameLabel.backgroundColor = [UIColor clearColor];
		albumNameLabel.textAlignment = UITextAlignmentLeft; // default
		albumNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[albumNameScrollView addSubview:albumNameLabel];
		[albumNameLabel release];
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
	result = [databaseControls.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text];
		
	while ([result next])
	{
		[databaseControls removeSongFromCacheDb:[NSString stringWithString:[result stringForColumnIndex:0]]];
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
	//DLog(@"blockerAction");
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
		
		//[self.downloadButton removeFromSuperview];
		//[self.queueButton removeFromSuperview];
		//[self.overlayView removeFromSuperview];
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
	result = [databaseControls.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text];
	
	while ([result next])
	{
		[databaseControls addSongToPlaylistQueue:[databaseControls songFromCacheDb:[NSString stringWithString:[result stringForColumnIndex:0]]]];
	}
	
	// Hide the loading screen
	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	
	[autoreleasePool release];
}

- (void)setSelected:(BOOL)selected animated:(BOOL)animated 
{
    [super setSelected:selected animated:animated];
	//self.contentView.backgroundColor = [UIColor whiteColor];
}


- (void)layoutSubviews {
	
    [super layoutSubviews];
	
	//self.contentView.frame = CGRectMake(0, 0, 320, 60);
	
	// Automatically set the width based on the width of the text
	albumNameLabel.frame = CGRectMake(0, 0, 230, 60);
	CGSize expectedLabelSize = [albumNameLabel.text sizeWithFont:albumNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:albumNameLabel.lineBreakMode]; 
	CGRect newFrame = albumNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	albumNameLabel.frame = newFrame;
	
	coverArtView.frame = CGRectMake(0, 0, 60, 60);
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
				
				if (albumNameLabel.frame.size.width > albumNameScrollView.frame.size.width)
				{
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:albumNameLabel.frame.size.width/(float)150];
						albumNameScrollView.contentOffset = CGPointMake(albumNameLabel.frame.size.width - albumNameScrollView.frame.size.width + 10, 0);
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
	[UIView setAnimationDuration:albumNameLabel.frame.size.width/(float)150];
		albumNameScrollView.contentOffset = CGPointZero;
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
	[seg1 release];
	/*[albumNameLabel release];
	[coverArtView release];*/
    [super dealloc];
}


@end
