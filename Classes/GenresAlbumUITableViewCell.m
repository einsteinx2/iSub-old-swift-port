//
//  AlbumUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "GenresAlbumUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "AsynchronousImageViewCached.h"
#import "FMDatabase.h"
#import "CellOverlay.h"

@implementation GenresAlbumUITableViewCell

@synthesize segment, seg1, genre, coverArtView, albumNameScrollView, albumNameLabel, isOverlayShowing, overlayView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		// Initialization code
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		musicControls = [MusicControlsSingleton sharedInstance];
		databaseControls = [DatabaseControlsSingleton sharedInstance];
		
		isOverlayShowing = NO;
		
		coverArtView = [[AsynchronousImageViewCached alloc] init];
		[self.contentView addSubview:coverArtView];
		[coverArtView release];
		
		albumNameScrollView = [[UIScrollView alloc] init];
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


- (void)downloadAction
{
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(downloadAllSongs) withObject:nil];
	
	overlayView.downloadButton.alpha = .3;
	overlayView.downloadButton.enabled = NO;
	
	[self hideOverlay];
}


- (void)downloadAllSongs
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	FMResultSet *result;
	if (viewObjects.isOfflineMode) 
	{
		result = [databaseControls.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
	}
	else 
	{
		result = [databaseControls.genresDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
	}
	
	while ([result next])
	{
		[databaseControls addSongToCacheQueue:[databaseControls songFromGenreDb:[result stringForColumnIndex:0]]];
	}
	
	if (musicControls.isQueueListDownloading == NO)
	{
		[musicControls performSelectorOnMainThread:@selector(downloadNextQueuedSong) withObject:nil waitUntilDone:NO];
	}
	
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
		
		if (viewObjects.isOfflineMode)
		{
			overlayView.downloadButton.enabled = NO;
			overlayView.downloadButton.hidden = YES;
		}
		
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
	if (viewObjects.isOfflineMode) 
	{
		result = [databaseControls.songCacheDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM cachedSongsLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
	}
	else 
	{
		//NSLog(@"%@", [NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = %@ AND seg%i = %@ AND genre = %@ ORDER BY seg%i COLLATE NOCASE", seg1, segment, albumNameLabel.text, genre, (segment + 1)]);
		result = [databaseControls.genresDb executeQuery:[NSString stringWithFormat:@"SELECT md5 FROM genresLayout WHERE seg1 = ? AND seg%i = ? AND genre = ? ORDER BY seg%i COLLATE NOCASE", segment, (segment + 1)], seg1, albumNameLabel.text, genre];
	}
	
	while ([result next])
	{
		[databaseControls addSongToPlaylistQueue:[databaseControls songFromGenreDb:[result stringForColumnIndex:0]]];
	}

	[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	
	[autoreleasePool release];
}


- (void)layoutSubviews {
	
    [super layoutSubviews];
	
	self.contentView.frame = CGRectMake(0, 0, 320, 60);
	albumNameScrollView.frame = CGRectMake(65, 0, 230, 60);
	
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
					[albumNameScrollView setContentOffset:CGPointMake(albumNameLabel.frame.size.width - albumNameScrollView.frame.size.width, 0) animated:YES];
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:albumNameLabel.frame.size.width/(float)150];
						albumNameScrollView.contentOffset = CGPointMake(albumNameLabel.frame.size.width - albumNameScrollView.frame.size.width, 0);
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
	[genre release];
	/*[albumNameLabel release];
	[coverArtView release];*/
    [super dealloc];
}


@end
