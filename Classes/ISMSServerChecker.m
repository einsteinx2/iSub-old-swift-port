//
//  ServerURLChecker.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSServerChecker.h"
#import "TBXML.h"
#import "NSError+ISMSError.h"
#import "NSMutableURLRequest+SUS.h"
#import "SavedSettings.h"
#import "SUSServerChecker.h"
#import "PMSServerChecker.h"
#import "Server.h"

@implementation ISMSServerChecker

@synthesize receivedData, delegate, request, isNewSearchAPI, connection;
@synthesize majorVersion, minorVersion, versionString;

- (id)initWithDelegate:(id<ISMSServerCheckerDelegate>)theDelegate
{
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		SUSServerChecker *checker = [[SUSServerChecker alloc] init];
		checker.delegate = theDelegate;
		return checker;
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX]) 
	{
		PMSServerChecker *checker = [[PMSServerChecker alloc] init];
		checker.delegate = theDelegate;
		return checker;
	}
	return nil;
}

- (void)checkServerUrlString:(NSString *)urlString username:(NSString *)username password:(NSString *)password
{
    assert(0 && "Must be subclassed");
}

- (void)checkTimedOut
{
	//DLog(@"check timed out");
	[self.connection cancel];
	NSError *error = [NSError errorWithISMSCode:ISMSErrorCode_CouldNotReachServer];
	[self connection:self.connection didFailWithError:error];
}

- (void)cancelLoad
{
	[self checkTimedOut];
}


@end
