//
//  PlayingUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CacheQueueSongUITableViewCell.h"
#import "AsynchronousImageView.h"
#import "ViewObjectsSingleton.h"
#import "NSNotificationCenter+MainThread.h"

@implementation CacheQueueSongUITableViewCell

@synthesize coverArtView, cacheInfoLabel, nameScrollView, songNameLabel, artistNameLabel, md5;

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		coverArtView = [[AsynchronousImageView alloc] init];
		coverArtView.isLarge = NO;
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

- (void)dealloc
{
	coverArtView.delegate = nil;
	coverArtView = nil;
	cacheInfoLabel = nil;
	nameScrollView = nil;
	songNameLabel = nil;
	artistNameLabel = nil;
	[super dealloc];
}

- (void)layoutSubviews
{	
    [super layoutSubviews];
	
	//self.deleteToggleImage.frame = CGRectMake(4, 28.5, 23, 23);
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

- (void)toggleDelete
{
	if (self.isDelete)
	{
		[viewObjectsS.multiDeleteList removeObject:self.md5];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hideDeleteButton"];
		self.deleteToggleImage.image = [UIImage imageNamed:@"unselected.png"];
	}
	else
	{
		[viewObjectsS.multiDeleteList addObject:self.md5];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"showDeleteButton"];
		self.deleteToggleImage.image = [UIImage imageNamed:@"selected.png"];
	}
	
	self.isDelete = !self.isDelete;
}

#pragma mark - Overlay

- (void)showOverlay
{
	return;
}

- (void)hideOverlay
{
	return;
}

#pragma mark - Scrolling

- (void)scrollLabels
{
	CGFloat scrollWidth = songNameLabel.frame.size.width > artistNameLabel.frame.size.width ? songNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	
	if (scrollWidth > nameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:scrollWidth/(float)150];
		nameScrollView.contentOffset = CGPointMake(scrollWidth - nameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = songNameLabel.frame.size.width > artistNameLabel.frame.size.width ? songNameLabel.frame.size.width : artistNameLabel.frame.size.width;
	
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/(float)150];
	nameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
