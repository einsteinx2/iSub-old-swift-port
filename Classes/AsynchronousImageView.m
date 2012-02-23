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

@implementation AsynchronousImageView

@synthesize coverArtId, isForPlayer;

- (id) initWithCoder:(NSCoder*)coder
{
    self = [super initWithCoder:(NSCoder*)coder];
	
    if (self != nil)
    {
		isForPlayer = NO;
    }
	
    return self;
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

#pragma mark - Load Image

// TODO: rewrite this to get DB calls out of this class

- (void)loadImageFromCoverArtId:(NSString *)artId isForPlayer:(BOOL)isPlayer
{
	self.coverArtId = artId;
	self.isForPlayer = isPlayer;
	
	
	NSString *size = nil;
	if (IS_IPAD())
	{
        size = @"540";
	}
	else
	{
		if (SCREEN_SCALE() == 2.0)
		{
            size = @"640";
		}
		else
		{	
            size = @"320";
		}
	}
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(size), @"size", n2N(artId), @"id", nil];
	DLog(@"parameters: %@", parameters);
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getCoverArt" andParameters:parameters];
	
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	data = [[NSMutableData data] retain];
}


- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
	{
		return YES; // Self-signed cert will be accepted
		// Note: it doesn't seem to matter what you return for a proper SSL cert, only self-signed certs
	}
	// If no other authentication is required, return NO for everything else
	// Otherwise maybe YES for NSURLAuthenticationMethodDefault and etc.
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[data setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [data appendData:incrementalData];
}


- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	DLog(@"Connection to album art failed");
	self.image = [UIImage imageNamed:@"default-album-art.png"];
	
	[data release]; data = nil;
	[connection release]; connection = nil;
}	


- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	// Check to see if the data is a valid image. If so, use it; if not, use the default image.
	if([UIImage imageWithData:data])
	{
		if (IS_IPAD())
		{
			[databaseS.coverArtCacheDb540 executeUpdate:@"INSERT OR REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [coverArtId md5], data];
		}
		else
		{
			[databaseS.coverArtCacheDb320 executeUpdate:@"INSERT OR REPLACE INTO coverArtCache (id, data) VALUES (?, ?)", [coverArtId md5], data];
		}
		
		if (SCREEN_SCALE() == 2.0 && !IS_IPAD())
		{
			UIGraphicsBeginImageContextWithOptions(CGSizeMake(320.0,320.0), NO, 2.0);
			[[UIImage imageWithData:data] drawInRect:CGRectMake(0,0,320,320)];
			self.image = UIGraphicsGetImageFromCurrentImageContext();
			UIGraphicsEndImageContext();
		}
		else
		{
			self.image = [UIImage imageWithData:data];
		}
	}
	else 
	{
		self.image = [UIImage imageNamed:@"default-album-art.png"];
	}
	
	//if (isForPlayer)
	//{
		[NSNotificationCenter postNotificationToMainThreadWithName:@"createReflection"];
	//}
	
	[data release]; data = nil;
	[connection release]; connection = nil;
}

- (void)dealloc 
{
	[coverArtId release];
	[super dealloc];
}

@end
