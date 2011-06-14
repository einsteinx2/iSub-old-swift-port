//
//  PlaylistSongUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistSongUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "FMDatabase.h"
#import "Song.h"
#import "CellOverlay.h"

@implementation CurrentPlaylistSongUITableViewCell

@synthesize indexPath, deleteToggleImage, isDelete, coverArtView, numberLabel, nameScrollView, songNameLabel, artistNameLabel, isOverlayShowing, overlayView;

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
		
		deleteToggleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"unselected.png"]];
		[self addSubview:deleteToggleImage];
		[deleteToggleImage release];
		
		coverArtView = [[AsynchronousImageViewCached alloc] init];
		[self.contentView addSubview:coverArtView];
		[coverArtView release];
		
		numberLabel = [[UILabel alloc] init];
		numberLabel.backgroundColor = [UIColor clearColor];
		numberLabel.textAlignment = UITextAlignmentCenter;
		numberLabel.font = [UIFont boldSystemFontOfSize:30];
		numberLabel.adjustsFontSizeToFitWidth = YES;
		numberLabel.minimumFontSize = 12;
		[self.contentView addSubview:numberLabel];
		[numberLabel release];		
				
		nameScrollView = [[UIScrollView alloc] init];
		nameScrollView.frame = CGRectMake(105, 0, 210, 60);
		nameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		nameScrollView.showsVerticalScrollIndicator = NO;
		nameScrollView.showsHorizontalScrollIndicator = NO;
		nameScrollView.userInteractionEnabled = NO;
		nameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:nameScrollView];
		[nameScrollView release];
		
		songNameLabel = [[UILabel alloc] init];
		songNameLabel.backgroundColor = [UIColor clearColor];
		songNameLabel.textAlignment = UITextAlignmentLeft; // default
		songNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[nameScrollView addSubview:songNameLabel];
		[songNameLabel release];
		
		artistNameLabel = [[UILabel alloc] init];
		artistNameLabel.backgroundColor = [UIColor clearColor];
		artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		artistNameLabel.font = [UIFont systemFontOfSize:15];
		[nameScrollView addSubview:artistNameLabel];
		[artistNameLabel release];
	}
	
	return self;
}


- (void)toggleDelete
{
	if (deleteToggleImage.image == [UIImage imageNamed:@"unselected.png"])
	{
		[viewObjects.multiDeleteList addObject:[NSNumber numberWithInt:indexPath.row]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"showDeleteButton" object:nil];
		//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
		deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	else
	{
		[viewObjects.multiDeleteList removeObject:[NSNumber numberWithInt:indexPath.row]];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"hideDeleteButton" object:nil];
		//NSLog(@"multiDeleteList: %@", viewObjects.multiDeleteList);
		deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	}
}


- (void)downloadAction
{
	if (musicControls.isShuffle) 
	{
		Song *aSong = [[databaseControls songFromDbRow:indexPath.row inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb] retain];
		[databaseControls addSongToCacheQueue:aSong];
		[aSong release];
	}
	else 
	{
		//NSLog(@"caching song from now playing playlist");
		Song *aSong = [[databaseControls songFromDbRow:indexPath.row inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb] retain];
		//NSLog(@"aSong.title = %@", aSong.title);
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
	//NSLog(@"queueAction");
	if (musicControls.isShuffle)
	{
		Song *aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"shufflePlaylist" inDatabase:databaseControls.currentPlaylistDb];
		[databaseControls queueSong:aSong];
		
		/*[databaseControls.currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylist SELECT * FROM shufflePlaylist WHERE ROWID = %i", indexPath.row + 1]];
		[databaseControls.currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO shufflePlaylist SELECT * FROM shufflePlaylist WHERE ROWID = %i", indexPath.row + 1]];*/
	}
	else
	{
		Song *aSong = [databaseControls songFromDbRow:indexPath.row inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		[databaseControls queueSong:aSong];
		
		//[databaseControls.currentPlaylistDb executeUpdate:[NSString stringWithFormat:@"INSERT INTO currentPlaylist SELECT * FROM currentPlaylist WHERE ROWID = %i", indexPath.row + 1]];
	}
	
	[self hideOverlay];
	[[NSNotificationCenter defaultCenter] postNotificationName:@"updateCurrentPlaylistCount" object:nil];
	[(UITableView*)self.superview reloadData];
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
		
		//[self.downloadButton removeFromSuperview];
		//[self.queueButton removeFromSuperview];
		//[self.overlayView removeFromSuperview];
	}
}


- (void)showOverlay
{
	if (!isOverlayShowing && !viewObjects.isEditing)
	{
		overlayView = [CellOverlay cellOverlayWithTableCell:self];
		[self.contentView addSubview:overlayView];
		
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
	
	deleteToggleImage.frame = CGRectMake(4.0, 18.5, 23.0, 23.0);
	coverArtView.frame = CGRectMake(0, 0, 60, 60);
	numberLabel.frame = CGRectMake(62, 0, 40, 60);
	
	// Automatically set the width based on the width of the text
	songNameLabel.frame = CGRectMake(0, 0, 190, 40);
	CGSize expectedLabelSize = [songNameLabel.text sizeWithFont:songNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:songNameLabel.lineBreakMode]; 
	CGRect newFrame = songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	songNameLabel.frame = newFrame;
	
	artistNameLabel.frame = CGRectMake(0, 37, 190, 20);
	expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:artistNameLabel.lineBreakMode]; 
	newFrame = artistNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	artistNameLabel.frame = newFrame;
}


- (void)setEditing:(BOOL)editing animated:(BOOL)animated
{
	if (viewObjects.isEditing)
		[super setEditing:editing animated:animated]; 
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

				if (scrollWidth > nameScrollView.frame.size.width)
				{
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:scrollWidth/(float)150];
					nameScrollView.contentOffset = CGPointMake(scrollWidth - nameScrollView.frame.size.width + 10, 0);
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
	nameScrollView.contentOffset = CGPointZero;
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
	
	/*[coverArtView release];
	[numberLabel release];
	[songNameLabel release];
	[artistNameLabel release];*/
    [super dealloc];
}


@end
