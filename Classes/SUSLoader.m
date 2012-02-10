//
//  Loader.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"
#import "SavedSettings.h"
#import "MusicSingleton.h"
#import "Song.h"

@implementation SUSLoader

@synthesize connection, receivedData;
@synthesize delegate, loadError;

- (void)setup
{
    loadError = nil;
    delegate = nil;
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

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
	self = [super init];
    if (self) 
	{
        [self setup];
		delegate = theDelegate;
        //DLog(@"init with delegate %@", delegate);
	}
	
	return self;
}

- (void)dealloc
{
	[loadError release]; loadError = nil;
    [super dealloc];
}

- (SUSLoaderType)type
{
    return SUSLoaderType_Generic;
}

- (void)startLoad
{
	[NSException raise:NSInternalInconsistencyException 
				format:@"You must override %@ in a subclass", NSStringFromSelector(_cmd)];
}

- (void)cancelLoad
{
	// Clean up connection objects
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
}

- (void) subsonicErrorCode:(NSInteger)errorCode message:(NSString *)message
{
	DLog(@"Subsonic error: %@", message);
	
	NSDictionary *dict = [NSDictionary dictionaryWithObject:message forKey:NSLocalizedDescriptionKey];
	NSError *error = [NSError errorWithDomain:SUSErrorDomain code:errorCode userInfo:dict];
	[self informDelegateLoadingFailed:error];
	
	/*if ([parseState isEqualToString: @"allAlbums"])
	{
		DLog(@"Subsonic error: %@", message);
	}
	else
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	 alert.tag = 1;
		[alert show];
		[alert release];
	}*/
}

- (BOOL)informDelegateLoadingFailed:(NSError *)error
{
	if ([delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[delegate loadingFailed:self withError:error];
		return YES;
	}
	
	DLog(@"delegate (%@) did not respond to loading failed", delegate);
	return NO;
}

- (BOOL)informDelegateLoadingFinished
{
	if ([delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[delegate loadingFinished:self];
		return YES;
	}
	
	DLog(@"delegate (%@) did not respond to loading finished", delegate);
	return NO;
}

@end