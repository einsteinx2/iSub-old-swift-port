//
//  AsynchronousImageView.m
//  GLOSS
//
//  Created by Слава on 22.10.09.
//  Copyright 2009 Slava Bushtruk. All rights reserved.
//  ---------------------------------------------------
//
//  Modified by Ben Baron for the iSub project.
//

// TODO: Make sure this class still works with songAtTimeOfLoad removed

#import "AsynchronousImageView.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "Song.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "PageControlViewController.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSNotificationCenter+MainThread.h"
#import "SUSCoverArtDAO.h"
#import "UIView+Tools.h"
#import "AsynchronousImageViewDelegate.h"

@implementation AsynchronousImageView

@synthesize coverArtDAO, coverArtId, isLarge, activityIndicator, delegate;

- (id)initWithFrame:(CGRect)frame coverArtId:(NSString *)artId isLarge:(BOOL)large delegate:(NSObject<AsynchronousImageViewDelegate> *)theDelegate
{
	if ((self = [super initWithFrame:frame]))
	{
		isLarge = large;
		self.coverArtId = artId;
		delegate = theDelegate;
	}
	return self;
}

- (NSString *)coverArtId
{
	@synchronized(self)
	{
		return coverArtId;
	}
}

- (void)setCoverArtId:(NSString *)artId
{
	@synchronized(self)
	{
		[coverArtId release];
		coverArtId = [artId copy];
		
		self.coverArtDAO = [[[SUSCoverArtDAO alloc] initWithDelegate:self coverArtId:self.coverArtId isLarge:self.isLarge] autorelease];
		if (self.coverArtDAO.isCoverArtCached)
		{
			self.image = self.coverArtDAO.coverArtImage;
		}
		else
		{
			self.image = self.coverArtDAO.defaultCoverArtImage;
			
			if (coverArtId && self.isLarge)
			{
				self.activityIndicator = [[[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleWhiteLarge] autorelease];
				self.activityIndicator.center = CGPointMake(self.width/2, self.height/2);
				[self addSubview:self.activityIndicator];
				[self.activityIndicator startAnimating];
				
				[self.coverArtDAO startLoad];
			}
		}
	}
}

#pragma mark -
#pragma mark Handle User Input

- (void)reloadCoverArt
{	
	/*if(musicS.currentSongObject.coverArtId)
	{
		musicS.coverArtUrl = nil;
		if (SCREEN_SCALE() == 2.0)
		{
			musicS.coverArtUrl = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@&size=640", [appDelegateS getBaseUrl:@"getCoverArt.view"], musicS.currentSongObject.coverArtId]];
		}
		else
		{	
			musicS.coverArtUrl = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@&size=320", [appDelegateS getBaseUrl:@"getCoverArt.view"], musicS.currentSongObject.coverArtId]];
		}
		[self loadImageFromURLString:[musicS.coverArtUrl absoluteString]];
	}
	else 
	{
		self.image = [UIImage imageNamed:@"default-album-art.png"];
	}*/
}

-(void)oneTap
{
	DLog(@"Single tap");
	PageControlViewController *pageControlViewController = [[PageControlViewController alloc] initWithNibName:@"PageControlViewController" bundle:nil];
	[self addSubview:pageControlViewController.view];
	[pageControlViewController showSongInfo];
}

-(void)twoTaps
{
	DLog(@"Double tap");
	[self reloadCoverArt];
}

-(void)threeTaps
{
	DLog(@"Triple tap");
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{
	// Detect touch anywhere
	UITouch *touch = [touches anyObject];
	
	switch ([touch tapCount]) 
	{
		case 1:
			[self performSelector:@selector(oneTap) withObject:nil afterDelay:.5];
			break;
			
		case 2:
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(oneTap) object:nil];
			[self performSelector:@selector(twoTaps) withObject:nil afterDelay:.5];
			break;
			
		case 3:
			[NSObject cancelPreviousPerformRequestsWithTarget:self selector:@selector(twoTaps) object:nil];
			[self performSelector:@selector(threeTaps) withObject:nil afterDelay:.5];
			break;
			
		default:
			break;
	}
}

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	self.coverArtDAO = nil;
	if ([delegate respondsToSelector:@selector(asyncImageViewLoadingFailed:withError:)])
	{
		[delegate asyncImageViewLoadingFailed:self withError:error];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	[self.activityIndicator removeFromSuperview];
	self.activityIndicator = nil;
	
	self.image = self.coverArtDAO.coverArtImage;
	self.coverArtDAO = nil;
	
	if ([delegate respondsToSelector:@selector(asyncImageViewFinishedLoading:)])
	{
		[delegate asyncImageViewFinishedLoading:self];
	}
}

- (void)dealloc 
{
	[self.activityIndicator removeFromSuperview];
	self.activityIndicator = nil;
	
	[coverArtDAO release]; coverArtDAO = nil;
	[coverArtId release]; coverArtId = nil;
	[super dealloc];
}

@end
