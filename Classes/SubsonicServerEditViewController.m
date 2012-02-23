//
//  SubsonicServerEditViewController.m
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SubsonicServerEditViewController.h"
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
#import "NSArray+Additions.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SubsonicServerEditViewController

@synthesize parentController, theNewRedirectUrl;

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
	
	if (!parentController)
	{
		CGRect frame = self.view.frame;
		frame.origin.y = 20;
		self.view.frame = frame;
	}
	
	
	theNewRedirectUrl = nil;
	
	if (viewObjectsS.serverToEdit)
	{
		urlField.text = viewObjectsS.serverToEdit.url;
		usernameField.text = viewObjectsS.serverToEdit.username;
		passwordField.text = viewObjectsS.serverToEdit.password;
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}

- (void)dealloc {
	[theNewRedirectUrl release]; theNewRedirectUrl = nil;
	[urlField release];
	[usernameField release];
	[passwordField release];
	[cancelButton release];
	[saveButton release];
    [super dealloc];
}

#pragma mark - Button handling

- (BOOL) checkUrl:(NSString *)url
{
	if ([url length] == 0)
		return NO;
	
	if ([[url substringFromIndex:([url length] - 1)] isEqualToString:@"/"])
	{
		urlField.text = [url substringToIndex:([url length] - 1)];
		return YES;
	}
	
	if ([url length] < 7)
	{
		urlField.text = [NSString stringWithFormat:@"http://%@", url];
		return YES;
	}
	else
	{
		if (![[url substringToIndex:7] isEqualToString:@"http://"] && ![[url substringToIndex:8] isEqualToString:@"https://"])
		{
			urlField.text = [NSString stringWithFormat:@"http://%@", url];
			return YES;
		}
	}
	
	return YES;
}


- (BOOL) checkUsername:(NSString *)username
{
	if ([username length] > 0)
		return YES;
	else
		return NO;
}

- (BOOL) checkPassword:(NSString *)password
{
	if ([password length] > 0)
		return YES;
	else
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
	if (![self checkUrl:urlField.text])
	{
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:@"The URL must be in the format: http://mywebsite.com:port/folder\n\nBoth the :port and /folder are optional" delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert show];
		[alert release];
	}
	
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
	
	if ([self checkUrl:urlField.text] && [self checkUsername:usernameField.text] && [self checkPassword:passwordField.text])
	{
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Checking Server"];
		
		SUSServerChecker *checker = [[SUSServerChecker alloc] initWithDelegate:self];
		[checker checkServerUrlString:urlField.text username:usernameField.text password:passwordField.text];
	}
}

#pragma mark - Server URL Checker delegate

- (void)SUSServerURLCheckRedirected:(SUSServerChecker *)checker redirectUrl:(NSURL *)url
{
    self.theNewRedirectUrl = [NSString stringWithFormat:@"%@://%@:%@", url.scheme, url.host, url.port];
    DLog(@"redirectUrlString: %@", theNewRedirectUrl);
}

- (void)SUSServerURLCheckFailed:(SUSServerChecker *)checker withError:(NSError *)error
{
	[checker release]; checker = nil;
	[viewObjectsS hideLoadingScreen];
	
	NSString *message = @"";
	if (error.code == ISMSErrorCode_IncorrectCredentials)
		message = @"Either your username or password is incorrect. Please try again";
	else
		message = [NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\nError code %i:\n%@", [error code], [error localizedDescription]];
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
}	
	
- (void)SUSServerURLCheckPassed:(SUSServerChecker *)checker
{
	DLog(@"server check passed");
	[checker release]; checker = nil;
	[viewObjectsS hideLoadingScreen];
	
	Server *theServer = [[Server alloc] init];
	theServer.url = urlField.text;
	theServer.username = usernameField.text;
	theServer.password = passwordField.text;
	theServer.type = SUBSONIC;
	
	
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
		
		NSDictionary *userInfo = nil;
		if (theNewRedirectUrl)
		{
			userInfo = [NSDictionary dictionaryWithObject:theNewRedirectUrl forKey:@"theNewRedirectUrl"];
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
		[defaults setObject:urlField.text forKey:@"url"];
		[defaults setObject:usernameField.text forKey:@"username"];
		[defaults setObject:passwordField.text forKey:@"password"];
		[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settingsS.serverList] forKey:@"servers"];
		[defaults synchronize];
		
		[NSNotificationCenter postNotificationToMainThreadWithName:@"reloadServerList"];
		[NSNotificationCenter postNotificationToMainThreadWithName:@"showSaveButton"];
		
		if (parentController)
			[parentController dismissModalViewControllerAnimated:YES];
		
		[self dismissModalViewControllerAnimated:YES];
		
		NSDictionary *userInfo = nil;
		if (theNewRedirectUrl)
		{
			userInfo = [NSDictionary dictionaryWithObject:theNewRedirectUrl forKey:@"theNewRedirectUrl"];
		}
		[NSNotificationCenter postNotificationToMainThreadWithName:@"switchServer" userInfo:userInfo];
	}
	
	[theServer release];
}

#pragma mark - UITextField delegate

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[urlField resignFirstResponder];
	[usernameField resignFirstResponder];
	[passwordField resignFirstResponder];
	return YES;
}

// This dismisses the keyboard when any area outside the keyboard is touched
- (void) touchesBegan :(NSSet *) touches withEvent:(UIEvent *)event
{
	[urlField resignFirstResponder];
	[usernameField resignFirstResponder];
	[passwordField resignFirstResponder];
	[super touchesBegan:touches withEvent:event ];
}

@end
