//
//  UpdateXMLParser.m
//  iSub
//
//  Created by bbaron on 8/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "UpdateXMLParser.h"
#import "CustomUIAlertView.h"


@implementation UpdateXMLParser

- (id) initXMLParser 
{	
	if ((self = [super init]))
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	}
	
	return self;
}


-(void)alertView:(CustomUIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex 
{
	if(buttonIndex == 1)
	{
		//http://itunes.apple.com/us/app/isub-music-streamer/id362920532?mt=8&ls=1
		[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms://itunes.com/apps/isubmusicstreamer"]];
		//[[UIApplication sharedApplication] openURL:[NSURL URLWithString:@"itms-apps://ax.itunes.apple.com/WebObjects/MZStore.woa/wa/viewSoftwareUpdate?id=id362920532"]];
	}
}


- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	/*CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error parsing the XML response. Maybe you forgot to set the right port for your server?" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
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
	
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:title message:finalMessage delegate:self cancelButtonTitle:@"Dismiss" otherButtonTitles:@"App Store", nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
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
		
		NSLog(@"currentVersionSplit: %@", currentVersionSplit);
		NSLog(@"newVersionSplit: %@", newVersionSplit);
		NSLog(@"currentVersionPadded: %@", currentVersionPadded);
		NSLog(@"newVersionPadded: %@", newVersionPadded);
		
		
		@try 
		{
			if (currentVersionSplit == nil || newVersionSplit == nil || [currentVersionSplit count] == 0 || [newVersionSplit count] == 0)
				return;
			
			if ([[newVersionPadded objectAtIndex:0] intValue] > [[currentVersionPadded objectAtIndex:0] intValue])
			{
				// Major version number is bigger, update is available
				[self showAlert];
			}
			else if ([[newVersionPadded objectAtIndex:0] intValue] == [[currentVersionPadded objectAtIndex:0] intValue])
			{
				if ([[newVersionPadded objectAtIndex:1] intValue] > [[currentVersionPadded objectAtIndex:1] intValue])
				{
					// Update is available
					[self showAlert];
				}
				else if ([[newVersionPadded objectAtIndex:1] intValue] == [[currentVersionPadded objectAtIndex:1] intValue])
				{
					if ([[newVersionPadded objectAtIndex:2] intValue] > [[currentVersionPadded objectAtIndex:2] intValue])
					{
						// Update is available
						[self showAlert];
					}				
				}
			}
		}
		@catch (NSException *exception) 
		{
			NSLog(@"Range exception checking update version - %@: %@", [exception name], [exception reason]);
		}
	}
}


- (void) dealloc 
{
	[super dealloc];
}

@end
