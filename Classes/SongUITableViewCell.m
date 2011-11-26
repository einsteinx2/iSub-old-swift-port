//
//  SongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/20/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "SongUITableViewCell.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "NSString+md5.h"
#import "CellOverlay.h"

@implementation SongUITableViewCell

@synthesize indexPath, mySong, trackNumberLabel, songNameScrollView, songNameLabel, artistNameLabel, songDurationLabel, isOverlayShowing, overlayView;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		// Initialization code
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		musicControls = [MusicSingleton sharedInstance];
		databaseControls = [DatabaseSingleton sharedInstance];
		
		isOverlayShowing = NO;
		
		trackNumberLabel = [[UILabel alloc] init];
		trackNumberLabel.frame = CGRectMake(0, 4, 30, 41);
		trackNumberLabel.backgroundColor = [UIColor clearColor];
		trackNumberLabel.textAlignment = UITextAlignmentCenter;
		trackNumberLabel.font = [UIFont boldSystemFontOfSize:22];
		trackNumberLabel.adjustsFontSizeToFitWidth = YES;
		trackNumberLabel.minimumFontSize = 16;
		[self.contentView addSubview:trackNumberLabel];
		[trackNumberLabel release];
		
		songNameScrollView = [[UIScrollView alloc] init];
		songNameScrollView.frame = CGRectMake(35, 0, 235, 50);
		songNameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songNameScrollView.showsVerticalScrollIndicator = NO;
		songNameScrollView.showsHorizontalScrollIndicator = NO;
		songNameScrollView.userInteractionEnabled = NO;
		songNameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:songNameScrollView];
		[songNameScrollView release];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft;
		songNameLabel.font = [UIFont systemFontOfSize:20];
		[songNameScrollView addSubview:songNameLabel];
		[songNameLabel release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft;
		artistNameLabel.font = [UIFont systemFontOfSize:13];
		artistNameLabel.textColor = [UIColor colorWithWhite:.4 alpha:1];
		[songNameScrollView addSubview:artistNameLabel];
		[artistNameLabel release];
		
		songDurationLabel = [[UILabel alloc] init];
		songDurationLabel.frame = CGRectMake(270, 0, 45, 41);
		songDurationLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		songDurationLabel.backgroundColor = [UIColor clearColor];
		songDurationLabel.textAlignment = UITextAlignmentRight;
		songDurationLabel.font = [UIFont systemFontOfSize:16];
		songDurationLabel.adjustsFontSizeToFitWidth = YES;
		songDurationLabel.minimumFontSize = 12;
		songDurationLabel.textColor = [UIColor grayColor];
		[self.contentView addSubview:songDurationLabel];
		[songDurationLabel release];
	}
	
	return self;
}

- (void)downloadAction
{
	[mySong addToCacheQueue];
	
	overlayView.downloadButton.alpha = .3;
	overlayView.downloadButton.enabled = NO;
	
	if (musicControls.isQueueListDownloading == NO)
	{
		[musicControls downloadNextQueuedSong];
	}
	
	[self hideOverlay];
}


// Empty function
- (void)toggleDelete
{
}


- (void)queueAction
{
	[databaseControls queueSong:mySong];
	
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
		if ([[databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cachedSongs WHERE md5 = ?", [mySong.path md5]] isEqualToString:@"YES"] || [[databaseControls.songCacheDb stringForQuery:@"SELECT finished FROM cacheQueue"] isEqualToString:@"YES"]) {
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


- (void)setSelected:(BOOL)selected animated:(BOOL)animated 
{
	//if(!isOverlayShowing)
	[super setSelected:selected animated:animated];
	
    // Configure the view for the selected state
}


- (void)layoutSubviews 
{
    [super layoutSubviews];
	
	//self.trackNumberLabel.frame = CGRectMake(0, 4, 30, 41);
	//self.songNameScrollView.frame = CGRectMake(35, 0, 235, 50);
	
	// Automatically set the width based on the width of the text
	songNameLabel.frame = CGRectMake(0, 0, 235, 37);
	CGSize expectedLabelSize = [songNameLabel.text sizeWithFont:songNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:songNameLabel.lineBreakMode]; 
	CGRect newFrame = songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	songNameLabel.frame = newFrame;
	
	artistNameLabel.frame = CGRectMake(0, 33, 235, 15);
	expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,60) lineBreakMode:artistNameLabel.lineBreakMode]; 
	newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	artistNameLabel.frame = newFrame;
	
	//self.songDurationLabel.frame = CGRectMake(270, 0, 45, 41);
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
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:songNameLabel.frame.size.width/(float)150];
					songNameScrollView.contentOffset = CGPointMake(songNameLabel.frame.size.width - songNameScrollView.frame.size.width + 10, 0);
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
	[UIView setAnimationDuration:songNameLabel.frame.size.width/(float)150];
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


- (void)dealloc 
{
	[indexPath release];
	[mySong release];
	
	/*[trackNumberLabel release];
	[songNameLabel release];
	[songDurationLabel release];
	[songNameScrollView release];
	[artistNameLabel release];*/
	[super dealloc];
}


@end
