//
//  SUSStatusLoader.m
//  iSub
//
//  Created by Ben Baron on 8/22/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "SUSStatusLoader.h"
#import "TBXML.h"

@implementation SUSStatusLoader
@synthesize urlString, username, password, isNewSearchAPI, majorVersion, minorVersion, versionString;

- (NSURLRequest *)createRequest
{
    if (!self.urlString || !self.username || !self.password)
        return nil;
    
    return [NSMutableURLRequest requestWithSUSAction:@"ping" urlString:urlString username:username password:password parameters:nil];
}

- (void)processResponse
{
    DLog(@"SUSStatusLoader: %@", [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding]);
    
    NSError *error;
    TBXML *tbxml = [[TBXML alloc] initWithXMLData:self.receivedData error:&error];
	if (error)
	{
		// This is not XML, so fail
        [self informDelegateLoadingFailed:error];
		[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckFailed];
	}
	else
	{
		TBXMLElement *root = tbxml.rootXMLElement;
		
        if ([[TBXML elementName:root] isEqualToString:@"subsonic-response"])
        {
			self.versionString = [TBXML valueOfAttributeNamed:@"version" forElement:root];
			if (self.versionString)
			{
				NSArray *splitVersion = [self.versionString componentsSeparatedByString:@"."];
				if ([splitVersion count] > 0)
				{
					self.majorVersion = [[splitVersion objectAtIndexSafe:0] intValue];
					if (self.majorVersion >= 2)
                    {
						self.isNewSearchAPI = YES;
                        self.isVideoSupported = YES;
                    }
					
					if ([splitVersion count] > 1)
					{
						self.minorVersion = [[splitVersion objectAtIndexSafe:1] intValue];
						if (self.majorVersion >= 1 && self.minorVersion >= 4)
							self.isNewSearchAPI = YES;
                        
                        if (self.majorVersion >= 1 && self.minorVersion >= 7)
                            self.isVideoSupported = YES;
					}
				}
			}
			
			//DLog(@"versionString: %@   majorVersion: %i  minorVersion: %i", self.versionString, self.majorVersion, self.minorVersion);
			
			TBXMLElement *error = [TBXML childElementNamed:@"error" parentElement:root];
			if (error)
			{
				if ([[TBXML valueOfAttributeNamed:@"code" forElement:error] isEqualToString:@"40"])
				{
					// Incorrect credentials, so fail
					NSError *anError = [NSError errorWithISMSCode:ISMSErrorCode_IncorrectCredentials];
                    [self informDelegateLoadingFailed:anError];
					[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckFailed];
				}
				else
				{
					// This is a Subsonic server, so pass
                    [self informDelegateLoadingFinished];
					[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckPassed];
				}
			}
			else
			{
				// This is a Subsonic server, so pass
                [self informDelegateLoadingFinished];
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckPassed];
			}
        }
        else
        {
            // This is not a Subsonic server, so fail
            NSError *anError = [NSError errorWithISMSCode:ISMSErrorCode_NotASubsonicServer];
			[self informDelegateLoadingFailed:anError];
			[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ServerCheckFailed];
        }
    }
}

@end
