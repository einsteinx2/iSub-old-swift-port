//
//  PlayingUITableViewCell.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "BookmarkUITableViewCell.h"
#import "AsynchronousImageView.h"

@implementation BookmarkUITableViewCell

#pragma mark - Lifecycle

- (id)initWithStyle:(UITableViewCellStyle)style reuseIdentifier:(NSString *)reuseIdentifier 
{
    if ((self = [super initWithStyle:style reuseIdentifier:reuseIdentifier])) 
	{
		_coverArtView = [[AsynchronousImageView alloc] init];
		_coverArtView.isLarge = NO;
		[self.contentView addSubview:_coverArtView];
		
		_bookmarkNameLabel = [[UILabel alloc] init];
		_bookmarkNameLabel.frame = CGRectMake(0, 0, 320, 20);
		_bookmarkNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_bookmarkNameLabel.textAlignment = UITextAlignmentCenter; // default
		_bookmarkNameLabel.backgroundColor = [UIColor blackColor];
		_bookmarkNameLabel.alpha = .65;
		_bookmarkNameLabel.font = [UIFont boldSystemFontOfSize:10];
		_bookmarkNameLabel.textColor = [UIColor whiteColor];
		[self.contentView addSubview:_bookmarkNameLabel];
		
		_nameScrollView = [[UIScrollView alloc] init];
		_nameScrollView.frame = CGRectMake(65, 20, 245, 55);
		_nameScrollView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_nameScrollView.backgroundColor = [UIColor clearColor];
		_nameScrollView.showsVerticalScrollIndicator = NO;
		_nameScrollView.showsHorizontalScrollIndicator = NO;
		_nameScrollView.userInteractionEnabled = NO;
		_nameScrollView.decelerationRate = UIScrollViewDecelerationRateFast;
		[self.contentView addSubview:_nameScrollView];
		
		_songNameLabel = [[UILabel alloc] init];
		_songNameLabel.backgroundColor = [UIColor clearColor];
		_songNameLabel.textAlignment = UITextAlignmentLeft; // default
		_songNameLabel.font = [UIFont boldSystemFontOfSize:20];
		[_nameScrollView addSubview:_songNameLabel];
		
		_artistNameLabel = [[UILabel alloc] init];
		_artistNameLabel.backgroundColor = [UIColor clearColor];
		_artistNameLabel.textAlignment = UITextAlignmentLeft; // default
		_artistNameLabel.font = [UIFont systemFontOfSize:15];
		[_nameScrollView addSubview:_artistNameLabel];
	}
	
	return self;
}

- (void)dealloc
{
	_coverArtView.delegate = nil;
}

- (void)layoutSubviews
{
    [super layoutSubviews];
	
	//self.deleteToggleImage.frame = CGRectMake(4, 28.5, 23, 23);
	self.coverArtView.frame = CGRectMake(0, 20, 60, 60);
	
	// Automatically set the width based on the width of the text
	self.songNameLabel.frame = CGRectMake(0, 0, 245, 35);
	CGSize expectedLabelSize = [self.songNameLabel.text sizeWithFont:self.songNameLabel.font constrainedToSize:CGSizeMake(1000,35) lineBreakMode:self.songNameLabel.lineBreakMode]; 
	CGRect frame = self.songNameLabel.frame;
	frame.size.width = expectedLabelSize.width;
	self.songNameLabel.frame = frame;
	
	self.artistNameLabel.frame = CGRectMake(0, 35, 245, 20);
	expectedLabelSize = [self.artistNameLabel.text sizeWithFont:self.artistNameLabel.font constrainedToSize:CGSizeMake(1000,20) lineBreakMode:self.artistNameLabel.lineBreakMode]; 
	frame = self.artistNameLabel.frame;
	frame.size.width = expectedLabelSize.width;
	self.artistNameLabel.frame = frame;
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
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	if (scrollWidth > self.nameScrollView.frame.size.width)
	{
		[UIView beginAnimations:@"scroll" context:nil];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:scrollWidth/150.];
		self.nameScrollView.contentOffset = CGPointMake(scrollWidth - self.nameScrollView.frame.size.width + 10, 0);
		[UIView commitAnimations];
	}
}

- (void)textScrollingStopped
{
	CGFloat scrollWidth = self.songNameLabel.frame.size.width > self.artistNameLabel.frame.size.width ? self.songNameLabel.frame.size.width : self.artistNameLabel.frame.size.width;
	[UIView beginAnimations:@"scroll" context:nil];
	[UIView setAnimationDuration:scrollWidth/150.];
	self.nameScrollView.contentOffset = CGPointZero;
	[UIView commitAnimations];
}

@end
