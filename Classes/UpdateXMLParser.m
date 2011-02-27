//
//  UpdateXMLParser.m
//  iSub
//
//  Created by bbaron on 8/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UpdateXMLParser.h"


@implementation UpdateXMLParser

- (id) initXMLParser 
{	
	if (self = [super init])
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	}
	
	return self;
}


-(void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex 
{
	if(buttonIndex == 1)
	{
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms://itunes.com/apps/isubmusicstreamer"]];
	}
}


- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	/*UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"There was an error parsing the XML response. Maybe you forgot to set the right port for your server?" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	[alert show];
	[alert release];
	[self retain];
	[appDelegate.currentTabBarController.view removeFromSuperview];*/
	
	NSLog(@"Error parsing update XML response");
}


- (void)showAlert
{
	NSString *title = [NSString stringWithFormat:@"Free Update %@ Available", newVersion];
	NSString *finalMessage = [message stringByReplacingOccurrencesOfString:@"\\n" withString:@"\n"];
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:title message:finalMessage delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"App Store", nil];
	[alert show];
	[alert release];
	[self retain];
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if([elementName isEqualToString:@"update"])
	{
		NSString *currentVersion = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
		newVersion = [attributeDict objectForKey:@"version"];
		message = [attributeDict objectForKey:@"message"];
		NSLog(@"currentVersion = %@", currentVersion);
		NSLog(@"newVersion = %@", newVersion);
		NSLog(@"message = %@", message);
		
		NSArray *currentVersionSplit = [currentVersion componentsSeparatedByString:@"."];
		NSArray *newVersionSplit = [newVersion componentsSeparatedByString:@"."];
		
		if ([[newVersionSplit objectAtIndex:0] intValue] > [[currentVersionSplit objectAtIndex:0] intValue])
		{
			// Update is available
			[self showAlert];
		}
		else if ([[newVersionSplit objectAtIndex:0] intValue] == [[currentVersionSplit objectAtIndex:0] intValue])
		{
			if ([[newVersionSplit objectAtIndex:1] intValue] > [[currentVersionSplit objectAtIndex:1] intValue])
			{
				// Update is available
				[self showAlert];
			}
			else if ([[newVersionSplit objectAtIndex:1] intValue] == [[currentVersionSplit objectAtIndex:1] intValue])
			{
				if ([[newVersionSplit objectAtIndex:2] intValue] > [[currentVersionSplit objectAtIndex:2] intValue])
				{
					// Update is available
					[self showAlert];
				}
			}
		}
		
	}
}


- (void) dealloc 
{
	[super dealloc];
}

@end
