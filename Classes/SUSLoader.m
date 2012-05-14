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
@synthesize delegate;

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

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
	self = [super init];
    if (self) 
	{
        [self setup];
		delegate = theDelegate;
	}
	
	return self;
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
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegateS cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	 alert.tag = 1;
		[alert show];
		[alert release];
	}*/
}

- (BOOL)informDelegateLoadingFailed:(NSError *)error
{
	if ([self.delegate respondsToSelector:@selector(loadingFailed:withError:)])
	{
		[self.delegate loadingFailed:self withError:error];
		return YES;
	}
	
	DLog(@"delegate (%@) did not respond to loading failed", self.delegate);
	return NO;
}

- (BOOL)informDelegateLoadingFinished
{
	if ([self.delegate respondsToSelector:@selector(loadingFinished:)])
	{
		[self.delegate loadingFinished:self];
		return YES;
	}
	
	DLog(@"delegate (%@) did not respond to loading finished", self.delegate);
	return NO;
}

@end
