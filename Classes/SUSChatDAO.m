//
//  SUSChatDAO.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSChatDAO.h"
#import "NSString-rfcEncode.h"
#import "SUSChatLoader.h"

@implementation SUSChatDAO
@synthesize loader;

#pragma mark - Lifecycle

- (void)setup
{
    
}

- (id)init
{
    self = [super init];
    if (self) 
	{
		[self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(id <LoaderDelegate>)theDelegate
{
	self = [super initWithDelegate:theDelegate];
    if (self) 
	{
		[self setup];
    }
    
    return self;
}

- (void)dealloc
{
    [loader release]; loader = nil;
	[super dealloc];
}

#pragma mark - Public DAO Methods

- (void)sendChatMessage:(NSString *)message
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	// Form the URL and send the message
	NSString *encodedMessage = [message stringByAddingRFC3875PercentEscapesUsingEncoding:NSUTF8StringEncoding];
	NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [loader getBaseUrlString:@"addChatMessage.view"], encodedMessage]];
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	[request startSynchronous];
	if ([request error])
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error posting the message." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 2;
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
		
		// Hide the loading screen
		[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	}
	else
	{
		// Hide the loading screen
		//[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
		
		// Connection worked, reload the table
		[self performSelectorOnMainThread:@selector(loadData) withObject:nil waitUntilDone:NO];
	}
	[url release];
	
	[textInput performSelectorOnMainThread:@selector(setText:) withObject:@"" waitUntilDone:NO];
	[textInput performSelectorOnMainThread:@selector(resignFirstResponder) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];
}

#pragma mark - Loader Manager Methods

- (void)restartLoad
{
    [self startLoad];
}

- (void)startLoad
{
    [indexNames release]; indexNames = nil;
    [indexPositions release]; indexPositions = nil;
    [indexCounts release]; indexCounts = nil;
    
    self.loader = [[[SUSRootFoldersLoader alloc] initWithDelegate:delegate] autorelease];
    [loader startLoad];
}

- (void)cancelLoad
{
    [loader cancelLoad];
    self.loader = nil;
}

@end
