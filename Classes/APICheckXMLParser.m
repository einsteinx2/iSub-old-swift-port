//
//  APICheckXMLParser.m
//  iSub
//
//  Created by Ben Baron on 12/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "APICheckXMLParser.h"
#import "ViewObjectsSingleton.h"
#import "iSubAppDelegate.h"
#import "CustomUIAlertView.h"
#import "NSString-md5.h"
#import "SavedSettings.h"

@implementation APICheckXMLParser

- (id)initXMLParser 
{	
	if ((self = [super init]))
	{
		appDelegate = [iSubAppDelegate sharedInstance];
		viewObjects = [ViewObjectsSingleton sharedInstance];
		isNewSearchAPI = NO;
	}
	return self;
}

- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	if (!viewObjects.isSettingsShowing)
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Subsonic Error" message:message delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
		[alert show];
		[alert release];
	}
}

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	if (!viewObjects.isSettingsShowing)
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Subsonic Error" message:[NSString stringWithFormat:@"There was an error parsing the API check XML response.\n\nError:%@", parseError.localizedDescription] delegate:appDelegate cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
		[alert show];
		[alert release];
	}
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{	
	if([elementName isEqualToString:@"error"])
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
	}
	else if ([elementName isEqualToString:@"subsonic-response"])
	{
		NSString *version = [attributeDict objectForKey:@"version"];
		/*CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Version" message:version delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
		[alert release];*/
		
		NSArray *splitVersion = [version componentsSeparatedByString:@"."];
		if ([splitVersion count] == 1)
		{
			NSUInteger ver = [[splitVersion objectAtIndex:0] intValue];
			if (ver >= 2)
				isNewSearchAPI = YES;
			else
				isNewSearchAPI = NO;
		}
		else if ([splitVersion count] > 1)
		{
			NSUInteger ver1 = [[splitVersion objectAtIndex:0] intValue];
			NSUInteger ver2 = [[splitVersion objectAtIndex:1] intValue];
			if ((ver1 >= 1 && ver2 >= 4) || (ver1 >= 2))
				isNewSearchAPI = YES;
			else
				isNewSearchAPI = NO;
		}
		
		[SavedSettings sharedInstance].isNewSearchAPI = isNewSearchAPI;
		/*NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [appDelegate.defaultUrl md5]];
		if (isNewSearchAPI)
			[appDelegate.settingsDictionary setObject:@"YES" forKey:key];
		else
			[appDelegate.settingsDictionary setObject:@"NO" forKey:key];
		[defaults setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
		[defaults synchronize];*/
	}	
}

@end
