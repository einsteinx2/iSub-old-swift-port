//
//  ChatXMLParser.m
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//  -------------------------------------------
//
//  Modified /heavily/ by Ben Baron for the iSub project.
//

#import "ChatXMLParser.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "ChatMessage.h"
#import "ServerListViewController.h"
#import "CustomUIAlertView.h"

@implementation ChatXMLParser


- (ChatXMLParser *) initXMLParser 
{	
	if ((self = [super init]))	
	{
		appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
		viewObjects = [ViewObjectsSingleton sharedInstance];
	}
	
	return self;
}


- (void) subsonicErrorCode:(NSString *)errorCode message:(NSString *)message
{
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:@"Settings", nil];
	[alert show];
	[alert release];
}


- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if(buttonIndex == 1)
	{
		ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
		
		if (appDelegate.currentTabBarController.selectedIndex == 4)
		{
			[appDelegate.currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
		}
		else
		{
			[(UINavigationController*)appDelegate.currentTabBarController.selectedViewController pushViewController:serverListViewController animated:YES];
		}
		
		[serverListViewController release];
	}	
}


- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict {
	
	if([elementName isEqualToString:@"error"])
	{
		[self subsonicErrorCode:[attributeDict objectForKey:@"code"] message:[attributeDict objectForKey:@"message"]];
	}
	else if([elementName isEqualToString:@"chatMessage"]) 
	{
		//Initialize the chat message.
		ChatMessage *aChatMessage = [[ChatMessage alloc] init];
		
		//Extract the attributes here.
		aChatMessage.timestamp = [[[attributeDict objectForKey:@"time"] substringToIndex:10] intValue];
		aChatMessage.user = [attributeDict objectForKey:@"username"];
		aChatMessage.message = [attributeDict objectForKey:@"message"];
		
		[viewObjects.chatMessages addObject:aChatMessage];
		
		[aChatMessage release];
	}
}


- (void) dealloc 
{
	[super dealloc];
}

@end
