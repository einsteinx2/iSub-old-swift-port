//
//  PMSServerEditViewControllerViewController.m
//  iSub
//
//  Created by Benjamin Baron on 6/12/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "PMSServerEditViewControllerViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "FoldersViewController.h"
#import "Server.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "ServerListViewController.h"
#import "ServerTypeViewController.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"

@implementation PMSServerEditViewControllerViewController

@synthesize parentController, theNewRedirectUrl;
@synthesize urlField, usernameField, passwordField, cancelButton, saveButton;

#pragma mark - Rotation

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

#pragma mark - Lifecycle

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	if (!self.parentController)
	{
		CGRect frame = self.view.frame;
		frame.origin.y = 20;
		self.view.frame = frame;
	}
	
	self.theNewRedirectUrl = nil;
	
	if (viewObjectsS.serverToEdit)
	{
		self.urlField.text = viewObjectsS.serverToEdit.url;
		self.usernameField.text = viewObjectsS.serverToEdit.username;
		self.passwordField.text = viewObjectsS.serverToEdit.password;
	}
}

#pragma mark - Button handling

- (BOOL)checkUrl:(NSString *)url
{
	if (url.length == 0)
		return NO;
	
	if ([[url substringFromIndex:(url.length - 1)] isEqualToString:@"/"])
	{
		urlField.text = [url substringToIndex:([url length] - 1)];
		return YES;
	}
	
	if (url.length < 7)
	{
		urlField.text = [NSString stringWithFormat:@"http://%@", url];
		return YES;
	}
	else
	{
		if (![[url substringToIndex:7] isEqualToString:@"http://"])
		{
			BOOL addHttp = NO;
			if (url.length >= 8)
			{
				if (![[url substringToIndex:8] isEqualToString:@"https://"])
					addHttp = YES;
			}
			else 
			{
				addHttp = YES;
			}
			
			if (addHttp)
				urlField.text = [NSString stringWithFormat:@"http://%@", url];
			
			return YES;
		}
	}
	
	return YES;
}

- (BOOL)checkUsername:(NSString *)username
{
	return username.length > 0;
}

- (BOOL)checkPassword:(NSString *)password
{
	return password.length > 0;
}

- (IBAction) cancelButtonPressed:(id)sender
{
	viewObjectsS.serverToEdit = nil;
	
	if (self.parentController)
		[self.parentController dismissModalViewControllerAnimated:YES];
	
	[self dismissModalViewControllerAnimated:YES];
	
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"servers"])
	{
		// Pop the view back
		if (appDelegateS.currentTabBarController.selectedIndex == 4)
		{
			[appDelegateS.currentTabBarController.moreNavigationController popToViewController:[appDelegateS.currentTabBarController.moreNavigationController.viewControllers objectAtIndexSafe:1] animated:YES];
		}
		else
		{
			[(UINavigationController*)appDelegateS.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
		}
	}
}


- (IBAction) saveButtonPressed:(id)sender
{
	if (![self checkUrl:urlField.text])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
	}
	
	if ([self checkUrl:urlField.text] && [self checkUsername:usernameField.text] && [self checkPassword:passwordField.text])
	{
		Server *theServer = [[Server alloc] init];
		theServer.url = self.urlField.text;
		theServer.username = self.usernameField.text;
		theServer.password = self.passwordField.text;
		theServer.type = WAVEBOX;
		
		if (!settingsS.serverList)
			settingsS.serverList = [NSMutableArray arrayWithCapacity:1];
		
		if(viewObjectsS.serverToEdit)
		{					
			// Replace the entry in the server list
			NSInteger index = [settingsS.serverList indexOfObject:viewObjectsS.serverToEdit];
			[settingsS.serverList replaceObjectAtIndex:index withObject:theServer];
			
			// Update the serverToEdit to the new details
			viewObjectsS.serverToEdit = theServer;
			
			// Save the plist values
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setObject:theServer.url forKey:@"url"];
			[defaults setObject:theServer.username forKey:@"username"];
			[defaults setObject:theServer.password forKey:@"password"];
			[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
			[defaults synchronize];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"reloadServerList"];
			[NSNotificationCenter postNotificationToMainThreadWithName:@"showSaveButton"];
			
			if (self.parentController)
				[self.parentController dismissModalViewControllerAnimated:YES];
			
			[self dismissModalViewControllerAnimated:YES];
			
			NSDictionary *userInfo = nil;
			if (self.theNewRedirectUrl)
			{
				userInfo = [NSDictionary dictionaryWithObject:self.theNewRedirectUrl forKey:@"theNewRedirectUrl"];
			}
			[NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer" userInfo:userInfo];
		}
		else
		{
			// Create the entry in serverList
			viewObjectsS.serverToEdit = theServer;
			[settingsS.serverList addObject:viewObjectsS.serverToEdit];
			
			// Save the plist values
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setObject:self.urlField.text forKey:@"url"];
			[defaults setObject:self.usernameField.text forKey:@"username"];
			[defaults setObject:self.passwordField.text forKey:@"password"];
			[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
			[defaults synchronize];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"reloadServerList"];
			[NSNotificationCenter postNotificationToMainThreadWithName:@"showSaveButton"];
			
			if (self.parentController)
				[self.parentController dismissModalViewControllerAnimated:YES];
			
			[self dismissModalViewControllerAnimated:YES];
			
			if (IS_IPAD())
				[appDelegateS.ipadRootViewController.menuViewController showHome];
			
			NSDictionary *userInfo = nil;
			if (self.theNewRedirectUrl)
			{
				userInfo = [NSDictionary dictionaryWithObject:self.theNewRedirectUrl forKey:@"theNewRedirectUrl"];
			}
			[NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer" userInfo:userInfo];
		}
	}
}

#pragma mark - UITextField delegate

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self.urlField resignFirstResponder];
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
	return YES;
}

// This dismisses the keyboard when any area outside the keyboard is touched
- (void) touchesBegan :(NSSet *) touches withEvent:(UIEvent *)event
{
	[self.urlField resignFirstResponder];
	[self.usernameField resignFirstResponder];
	[self.passwordField resignFirstResponder];
	[super touchesBegan:touches withEvent:event];
}

@end
