//
//  AllAlbumsUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AllSongsUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "CellOverlay.h"

@implementation AllSongsUITableViewCell

@synthesize indexPath, md5, coverArtView, songNameScrollView, songNameLabel, artistNameLabel, isOverlayShowing, overlayView;

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
		
		songNameScrollView = [[UIScrollView alloc] init];
		songNameScrollView.frame = CGRectMake(65, 0, 255, 60);
		songNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameScrollView.showsVerticalScrollIndicator = NO;
		songNameScrollView.showsHorizontalScrollIndicator = NO;
		songNameScrollView.userInteractionEnabled = NO;
		songNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:songNameScrollView];
		[songNameScrollView release];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft; // default
		songNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[songNameScrollView addSubview:songNameLabel];
		[songNameLabel release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont systemFontOfSize:15];
		[songNameScrollView addSubview:artistNameLabel];
		[artistNameLabel release];
	}
	
	return self;
}

// Empty function
- (void)toggleDelete
{
}


- (void)downloadAction
{
	if (viewObjects.isSearchingAllSongs) 
	{
		Song *aSong = [[databaseControls songFromDbRow:indexPath.row inTable:@"allSongsSearch" inDatabase:databaseControls.allSongsDb] retain];
		[databaseControls addSongToCacheQueue:aSong];
		[aSong release];
	}
	else 
	{
		Song *aSong = [[databaseControls songFromDbRow:indexPath.row inTable:@"allSongs" inDatabase:databaseControls.allSongsDb] retain];
		[databaseControls addSongToCacheQueue:aSong];
		[aSong release];
	}
	
	overlayView.downloadButton.alpha = .3;
	overlayView.downloadButton.enabled = NO;
	
	if (musicControls.isQueueListDownloading == NO)
	{
		[musicControls downloadNextQueuedSong];
	}
	
	[self hideOverlay];
}


- (void)queueAction
{	
	if (viewObjects.isSearchingAllSongs) 
	{
		Song *aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"allSongsSearch" inDatabase:databaseControls.allSongsDb];
		[databaseControls queueSong:aSong];
	}
	else 
	{
		Song *aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"allSongs" inDatabase:databaseControls.allSongsDb];
		[databaseControls queueSong:aSong];
	}
	
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

		//NSLog(@"SELECT finished FROM cachedSongs WHERE md5 = %@", md5);
		//NSLog(@"%@", [databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", md5]);
		if ([[databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", md5] isEqualToString:@"YES"]) {
			overlayView.downloadButton.alpha = .3;
			overlayView.downloadButton.enabled = NO;
		}
		else {
			overlayView.downloadButton.alpha = .8;
			[overlayView.downloadButton addTarget:self action:@selector(downloadAction) forControlEvents:UIControlEventTouchUpInside];
			overlayView.downloadButton.enabled = YES;
		}
		
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
		overlayView.alpha = 1.0;
		[UIView commitAnimations];		
		
		isOverlayShowing = YES;
	}
}


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)layoutSubviews {
	
    [super layoutSubviews];
	
	coverArtView.frame = CGRectMake(0, 0, 60, 60);
	
	// Automatically set the width based on the width of the text
	songNameLabel.frame = CGRectMake(0, 0, 225, 35);
	CGSize expectedLabelSize = [songNameLabel.text sizeWithFont:songNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:songNameLabel.lineBreakMode]; 
	CGRect newFrame = songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	songNameLabel.frame = newFrame;
	
	artistNameLabel.frame = CGRectMake(0, 35, 225, 20);
	expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:artistNameLabel.lineBreakMode]; 
	newFrame = artistNameLabel.frame;
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
				
				if (songNameLabel.frame.size.width > artistNameLabel.frame.size.width)
					scrollWidth = songNameLabel.frame.size.width;
				else
					scrollWidth = artistNameLabel.frame.size.width;
				
				if (scrollWidth > songNameScrollView.frame.size.width)
				{
					[songNameScrollView setContentOffset:CGPointMake(scrollWidth - songNameScrollView.frame.size.width, 0) animated:YES];
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:scrollWidth/(float)150];
					songNameScrollView.contentOffset = CGPointMake(scrollWidth - songNameScrollView.frame.size.width, 0);
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
	[UIView setAnimationDuration:scrollWidth/(float)150];
	songNameScrollView.contentOffset = CGPointZero;
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
	[md5 release];
	
	/*[artistNameLabel release];
	[songNameScrollView release];
	[songNameLabel release];
	[coverArtView release];*/
    [super dealloc];
}


@end
