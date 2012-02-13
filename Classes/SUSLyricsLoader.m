//
//  SUSLyricsLoader.m
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLyricsLoader.h"
#import "TBXML.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"

#import "NSString+rfcEncode.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SUSLyricsLoader

@synthesize loadedLyrics, artist, title;

#pragma mark - Lifecycle

- (void)setup
{
	[super setup];
}

- (void)dealloc
{
	self.delegate = nil;
	[super dealloc];
}

- (FMDatabase *)db
{
    return [DatabaseSingleton sharedInstance].lyricsDb;
}

- (SUSLoaderType)type
{
    return SUSLoaderType_Lyrics;
}

#pragma mark - Loader Methods

- (void)startLoad
{
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:n2N(artist), @"artist", n2N(title), @"title", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getLyrics" andParameters:parameters];
   
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData data];
	} 
	else 
	{
		NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotCreateConnection];
		[self informDelegateLoadingFailed:error];
	}
}

#pragma mark - Private DB Methods

- (void)insertLyricsIntoDb
{
    [self.db synchronizedExecuteUpdate:@"INSERT INTO lyrics (artist, title, lyrics) VALUES (?, ?, ?)", artist, title, self.loadedLyrics];
    if ([self.db hadError]) { 
        DLog(@"Err inserting lyrics %d: %@", [self.db lastErrorCode], [self.db lastErrorMessage]); 
    }
}

#pragma mark - Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
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
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
    self.loadedLyrics = nil;
    
	self.receivedData = nil;
	self.connection = nil;
	
	// Inform the delegate that loading failed
	[self informDelegateLoadingFailed:error];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	    
    // Parse the data
	//
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
		TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
		if (error)
		{
			NSString *code = [TBXML valueOfAttributeNamed:@"code" forElement:error];
			NSString *message = [TBXML valueOfAttributeNamed:@"message" forElement:error];
			[self subsonicErrorCode:[code intValue] message:message];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
		}
		else
		{
			TBXMLElement *lyrics = [TBXML childElementNamed:@"lyrics" parentElement:root];
			if (lyrics)
			{
                self.loadedLyrics = [TBXML textForElement:lyrics];
				if ([self.loadedLyrics isEqualToString:@""])
				{
					DLog(@"lyrics tag found, but it's empty");
					self.loadedLyrics = nil;
					NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsFound];
					[self informDelegateLoadingFailed:error];
				}
				else
				{
					DLog(@"lyrics tag found, and it's got lyrics! \\o/");
					[self insertLyricsIntoDb];
					[self informDelegateLoadingFinished];
					
					[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsDownloaded];
				}
			}
            else
            {
				DLog(@"no lyrics tag found");
                self.loadedLyrics = nil;
                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self informDelegateLoadingFailed:error];
				
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
            }
		}
	}
    else
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
        [self informDelegateLoadingFailed:error];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_LyricsFailed];
    }
	[tbxml release];
	
	self.receivedData = nil;
	self.connection = nil;
}

@end
