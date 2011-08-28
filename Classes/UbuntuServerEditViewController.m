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
#import "MusicControlsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "RootViewController.h"
#import "XMLParser.h"
#import "Server.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"

#define URL @"https://streaming.one.ubuntu.com"

@implementation UbuntuServerEditViewController

@synthesize parentController;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	//if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] && inOrientation != UIInterfaceOrientationPortrait)
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
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
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	
	if (viewObjects.serverToEdit)
	{
		usernameField.text = viewObjects.serverToEdit.username;
		passwordField.text = viewObjects.serverToEdit.password;
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
	viewObjects.serverToEdit = nil;
	
	if (parentController)
		[parentController dismissModalViewControllerAnimated:YES];
	
	[self dismissModalViewControllerAnimated:YES];
	
	if (![[NSUserDefaults standardUserDefaults] objectForKey:@"servers"])
	{
		// Pop the view back
		if (appDelegate.currentTabBarController.selectedIndex == 4)
		{
			[appDelegate.currentTabBarController.moreNavigationController popToViewController:[appDelegate.currentTabBarController.moreNavigationController.viewControllers objectAtIndex:1] animated:YES];
		}
		else
		{
			[(UINavigationController*)appDelegate.currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
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
		
		if (viewObjects.serverList == nil)
			viewObjects.serverList = [NSMutableArray arrayWithCapacity:1];
		
		if(viewObjects.serverToEdit)
		{					
			// Replace the entry in the server list
			NSInteger index = [viewObjects.serverList indexOfObject:viewObjects.serverToEdit];
			[viewObjects.serverList replaceObjectAtIndex:index withObject:theServer];
			
			// Update the serverToEdit to the new details
			viewObjects.serverToEdit = theServer;
			
			// Save the plist values
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setObject:theServer.url forKey:@"url"];
			[defaults setObject:theServer.username forKey:@"username"];
			[defaults setObject:theServer.password forKey:@"password"];
			[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:viewObjects.serverList] forKey:@"servers"];
			[defaults synchronize];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadServerList" object:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"showSaveButton" object:nil];
			
			if (parentController)
				[parentController dismissModalViewControllerAnimated:YES];
			
			[self dismissModalViewControllerAnimated:YES];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:@"switchServer" object:nil];
		}
		else
		{
			// Create the entry in serverList
			viewObjects.serverToEdit = theServer;
			[viewObjects.serverList addObject:viewObjects.serverToEdit];
			
			// Save the plist values
			NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
			[defaults setObject:URL forKey:@"url"];
			[defaults setObject:usernameField.text forKey:@"username"];
			[defaults setObject:passwordField.text forKey:@"password"];
			[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:viewObjects.serverList] forKey:@"servers"];
			[defaults synchronize];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadServerList" object:nil];
			[[NSNotificationCenter defaultCenter] postNotificationName:@"showSaveButton" object:nil];
			
			if (parentController)
				[parentController dismissModalViewControllerAnimated:YES];
			
			[self dismissModalViewControllerAnimated:YES];
			
			[[NSNotificationCenter defaultCenter] postNotificationName:@"switchServer" object:nil];
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

- (void)viewDidUnload 
{
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
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
