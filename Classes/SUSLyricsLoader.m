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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString+rfcEncode.h"

@implementation SUSLyricsLoader

@synthesize loadedLyrics, artist, title;

#pragma mark - Lifecycle

- (void)setup
{
	[super setup];
}

- (void)dealloc
{
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
		[self.delegate loadingFailed:self withError:error]; 
	}
}

#pragma mark - Private DB Methods

- (void)insertLyricsIntoDb
{
    [self.db executeUpdate:@"INSERT INTO lyrics (artist, title, lyrics) VALUES (?, ?, ?)", artist, title, self.loadedLyrics];
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
	[self.delegate loadingFailed:self withError:error];
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
		}
		else
		{
			TBXMLElement *lyrics = [TBXML childElementNamed:@"lyrics" parentElement:root];
			if (lyrics)
			{
                self.loadedLyrics = [TBXML textForElement:lyrics];
                [self insertLyricsIntoDb];
                [self.delegate loadingFinished:self];
			}
            else
            {
                self.loadedLyrics = nil;
                NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
                [self.delegate loadingFailed:self withError:error];
            }
		}
	}
    else
    {
        NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_NoLyricsElement];
        [self.delegate loadingFailed:self withError:error];
    }
	[tbxml release];
	
	self.receivedData = nil;
	self.connection = nil;
	
	// Notify the delegate that the loading is finished
	[self.delegate loadingFinished:self];
}

@end
