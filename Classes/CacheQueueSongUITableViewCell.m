//
//  PlayingUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheQueueSongUITableViewCell.h"
#import "AsynchronousImageViewCached.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"

@implementation CacheQueueSongUITableViewCell

@synthesize coverArtView, cacheInfoLabel, nameScrollView, songNameLabel, artistNameLabel;
@synthesize indexPath, deleteToggleImage, isDelete;

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		// Initialization code
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
 		
		deleteToggleImage = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"unselected.png"]];
		[self addSubview:deleteToggleImage];
		[deleteToggleImage release];
		
		coverArtView = [[AsynchronousImageViewCached alloc] init];
		[self.contentView addSubview:coverArtView];
		[coverArtView release];
		
		cacheInfoLabel = [[UILabel alloc] init];
		cacheInfoLabel.frame = CGRectMake(0, 0, 320, 20);
		cacheInfoLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		cacheInfoLabel.textAlignment = UITextAlignmentCenter; // default
		cacheInfoLabel.backgroundColor = [UIColor blackColor];
		cacheInfoLabel.alpha = .65;
		cacheInfoLabel.font = [UIFont boldSystemFontOfSize:10];
		cacheInfoLabel.textColor = [UIColor whiteColor];
		[self.contentView addSubview:cacheInfoLabel];
		[cacheInfoLabel release];
		
		nameScrollView = [[UIScrollView alloc] init];
		nameScrollView.frame = CGRectMake(65, 20, 245, 55);
		nameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		nameScrollView.backgroundColor = [UIColor clearColor];
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


- (void) hideOverlay
{
}

- (void) showOverlay
{
}

- (void) isOverlayShowing
{	
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


- (void)setSelected:(BOOL)selected animated:(BOOL)animated {

    [super setSelected:selected animated:animated];

    // Configure the view for the selected state
}


- (void)layoutSubviews {
	
    [super layoutSubviews];
	
	deleteToggleImage.frame = CGRectMake(4, 28.5, 23, 23);
	coverArtView.frame = CGRectMake(0, 20, 60, 60);
	
	
	// Automatically set the width based on the width of the text
	songNameLabel.frame = CGRectMake(0, 0, 245, 35);
	CGSize expectedLabelSize = [songNameLabel.text sizeWithFont:songNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:songNameLabel.lineBreakMode]; 
	CGRect newFrame = songNameLabel.frame;
	newFrame.size.width = expectedLabelSize.width;
	songNameLabel.frame = newFrame;
	
	artistNameLabel.frame = CGRectMake(0, 35, 245, 20);
	expectedLabelSize = [artistNameLabel.text sizeWithFont:artistNameLabel.font constrainedToSize:CGSizeMake(1000,20) lineBreakMode:artistNameLabel.lineBreakMode]; 
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
- (void)lookForSwipeGestureInTouches:(NSSet *)touches withEvent:(UIEvent *)event 
{
    UITouch *touch = [touches anyObject];
    CGPoint currentTouchPosition = [touch locationInView:self];
	
	[self setSelected:NO];
	swiping = YES;
		
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
					[nameScrollView setContentOffset:CGPointMake(scrollWidth - nameScrollView.frame.size.width, 0) animated:YES];
					[UIView beginAnimations:@"scroll" context:nil];
					[UIView setAnimationDelegate:self];
					[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
					[UIView setAnimationDuration:scrollWidth/(float)150];
					nameScrollView.contentOffset = CGPointMake(scrollWidth - nameScrollView.frame.size.width, 0);
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
	[cacheInfoLabel release];
	[nameScrollView release];
	[songNameLabel release];
	[artistNameLabel release];*/
    [super dealloc];
}


@end
