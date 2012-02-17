//
//  ISMSUpdateChecker.m
//  iSub
//
//  Created by Ben Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "ISMSUpdateChecker.h"
#import "TBXML.h"
#import "NSArray+Additions.h"

@implementation ISMSUpdateChecker
@synthesize receivedData, connection, request, theNewVersion, message;

- (void)checkForUpdate
{
    self.receivedData = [NSMutableData dataWithCapacity:0];
	self.request = [NSURLRequest requestWithURL:[NSURL URLWithString:@"http://isubapp.com/update.xml"]];
	self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (!self.connection)
	{
		self.receivedData = nil;
		self.request = nil;
	}
	
	// Take ownership of self to allow connection to finish and alertview button to be pressed
	[self retain];
}

- (void)showAlert
{
	NSString *title = [NSString stringWithFormat:@"Free Update %@ Available", theNewVersion];
	NSString *finalMessage = [message stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:finalMessage delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"App Store", nil];
	[alert show];
	[alert release];
}

-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex 
{
	if(buttonIndex == 1)
	{
		//http://itunes.apple.com/us/app/isub-music-streamer/id362920532?mt=8&ls=1
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms://itunes.com/apps/isubmusicstreamer"]];
		//[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftwareUpdate?id=id362920532"]];
	}
	
	[self release];
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
	[receivedData setLength:0];
}

- (NSURLRequest *)connection:(NSURLConnection *)inConnection willSendRequest:(NSURLRequest *)inRequest redirectResponse:(NSURLResponse *)inRedirectResponse
{
    if (inRedirectResponse) 
    {
        NSMutableURLRequest *r = [[request mutableCopy] autorelease]; // original request
        [r setURL:[inRequest URL]];
        return r;
    } 
    else 
    {
        return inRequest;
    }
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{    	
    self.connection = nil;
    self.receivedData = nil;
	self.request = nil;

	[self release];
}

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{		
	// TODO: test this
	BOOL showAlert = NO;
	//DLog(@"receivedData: %@", [[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding] autorelease]);
	TBXML *tbxml = [[TBXML alloc] initWithXMLData:receivedData];
    TBXMLElement *root = tbxml.rootXMLElement;
    if (root) 
	{
        if ([[TBXML elementName:root] isEqualToString:@"update"])
        {
			NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
			self.theNewVersion = [TBXML valueOfAttributeNamed:@"version" forElement:root];
			self.message = [TBXML valueOfAttributeNamed:@"message" forElement:root];
			//DLog(@"currentVersion = %@", currentVersion);
			//DLog(@"theNewVersion = %@", theNewVersion);
			//DLog(@"message = %@", message);
			
			NSArray *currentVersionSplit = [currentVersion componentsSeparatedByString:@"."];
			NSArray *newVersionSplit = [theNewVersion componentsSeparatedByString:@"."];
			
			NSMutableArray *currentVersionPadded = [NSMutableArray arrayWithArray:currentVersionSplit];
			NSMutableArray *newVersionPadded = [NSMutableArray arrayWithArray:newVersionSplit];
			
			if ([currentVersionPadded count] < 3)
			{
				for (int i = [currentVersionPadded count]; i < 3; i++)
				{
					[currentVersionPadded addObject:@"0"];
				}
			}
			
			if ([newVersionPadded count] < 3)
			{
				for (int i = [newVersionPadded count]; i < 3; i++)
				{
					[newVersionPadded addObject:@"0"];
				}
			}

			//DLog(@"currentVersionSplit: %@", currentVersionSplit);
			//DLog(@"newVersionSplit: %@", newVersionSplit);
			//DLog(@"currentVersionPadded: %@", currentVersionPadded);
			//DLog(@"newVersionPadded: %@", newVersionPadded);
			
			@try 
			{
				if (currentVersionSplit == nil || newVersionSplit == nil || [currentVersionSplit count] == 0 || [newVersionSplit count] == 0)
					return;
				
				if ([[newVersionPadded objectAtIndexSafe:0] intValue] > [[currentVersionPadded objectAtIndexSafe:0] intValue])
				{
					// Major version number is bigger, update is available
					showAlert = YES;
				}
				else if ([[newVersionPadded objectAtIndexSafe:0] intValue] == [[currentVersionPadded objectAtIndexSafe:0] intValue])
				{
					if ([[newVersionPadded objectAtIndexSafe:1] intValue] > [[currentVersionPadded objectAtIndexSafe:1] intValue])
					{
						// Update is available
						showAlert = YES;
					}
					else if ([[newVersionPadded objectAtIndexSafe:1] intValue] == [[currentVersionPadded objectAtIndexSafe:1] intValue])
					{
						if ([[newVersionPadded objectAtIndexSafe:2] intValue] > [[currentVersionPadded objectAtIndexSafe:2] intValue])
						{
							// Update is available
							showAlert = YES;
						}				
					}
				}
			}
			@catch (NSException *exception) 
			{
				DLog(@"Range exception checking update version - %@: %@", [exception name], [exception reason]);
			}
		}
	}
	[tbxml release];
    
	self.connection = nil;
    self.receivedData = nil;
	self.request = nil;
	
	if (showAlert)
		[self showAlert];
	else
		[self release];
}

@end