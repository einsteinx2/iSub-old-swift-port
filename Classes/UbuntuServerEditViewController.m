//
//  UbuntuServerEditViewController.m
//  iSub
//
//  Created by Ben Baron on 1/15/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "UbuntuServerEditViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "FoldersViewController.h"
#import "Server.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSArray+Additions.h"
#import "NSNotificationCenter+MainThread.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"

#define URL @"https://streaming.one.ubuntu.com"

@implementation UbuntuServerEditViewController

@synthesize parentController;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	if (!parentController)
	{
		CGRect frame = self.view.frame;
		frame.origin.y = 20;
		self.view.frame = frame;
	}
	
	
	if (viewObjectsS.serverToEdit)
	{
		usernameField.text = viewObjectsS.serverToEdit.username;
		passwordField.text = viewObjectsS.serverToEdit.password;
	}
}

- (BOOL) checkUsername:(NSString *)username
{
	if ([username length] > 0)
		return YES;
	
	return NO;
}

- (BOOL) checkPassword:(NSString *)password
{
	if ([password length] > 0)
		return YES;
	
	return NO;
}


- (IBAction) cancelButtonPressed:(id)sender
{
	viewObjectsS.serverToEdit = nil;
	
	if (parentController)
		[parentController dismissModalViewControllerAnimated:YES];
	
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
	
	if (![self checkUsername:usernameField.text])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please enter a username" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
	
	if (![self checkPassword:passwordField.text])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"Please enter a password" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
	
	if ([self checkUsername:usernameField.text] && [self checkPassword:passwordField.text])
	{
		Server *theServer = [[Server alloc] init];
		theServer.url = URL;
		theServer.username = usernameField.text;
		theServer.password = passwordField.text;
		theServer.type = UBUNTU_ONE;
		
		if (settingsS.serverList == nil)
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
			
			if (parentController)
				[parentController dismissModalViewControllerAnimated:YES];
			
			[self dismissModalViewControllerAnimated:YES];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer"];
		}
		else
		{
			// Create the entry in serverList
			viewObjectsS.serverToEdit = theServer;
			[settingsS.serverList addObject:viewObjectsS.serverToEdit];
			
			// Save the plist values
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setObject:URL forKey:@"url"];
			[defaults setObject:usernameField.text forKey:@"username"];
			[defaults setObject:passwordField.text forKey:@"password"];
			[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
			[defaults synchronize];
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"reloadServerList"];
			[NSNotificationCenter postNotificationToMainThreadWithName:@"showSaveButton"];
			
			[self dismissModalViewControllerAnimated:YES];
			
			if (parentController)
				[parentController dismissModalViewControllerAnimated:YES];

			if (IS_IPAD())
				[appDelegateS.ipadRootViewController.menuViewController showHome];
				
			
			[NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer"];
		}
		
		[theServer release];
	}
}


// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[usernameField resignFirstResponder];
	[passwordField resignFirstResponder];
	return YES;
}

// This dismisses the keyboard when any area outside the keyboard is touched
- (void) touchesBegan :(NSSet *) touches withEvent:(UIEvent *)event
{
	[usernameField resignFirstResponder];
	[passwordField resignFirstResponder];
	[super touchesBegan:touches withEvent:event ];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[usernameField release];
	[passwordField release];
	[cancelButton release];
	[saveButton release];
    [super dealloc];
}

@end
