//
//  ServerTypeViewController.m
//  iSub
//
//  Created by Ben Baron on 1/13/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ServerTypeViewController.h"
#import "SubsonicServerEditViewController.h"
#import "UbuntuServerEditViewController.h"
#import "iSubAppDelegate.h"
#import "SavedSettings.h"

@implementation ServerTypeViewController
@synthesize subsonicButton, ubuntuButton, cancelButton, serverEditViewController;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (IBAction)buttonAction:(id)sender
{
	UIView *subView = nil;

	if (sender == self.subsonicButton)
	{
		SubsonicServerEditViewController *subsonicServerEditViewController = [[SubsonicServerEditViewController alloc] initWithNibName:@"SubsonicServerEditViewController" bundle:nil];
		subsonicServerEditViewController.parentController = self;
		subsonicServerEditViewController.view.frame = self.view.bounds;
		subsonicServerEditViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		subView = subsonicServerEditViewController.view;
		self.serverEditViewController = subsonicServerEditViewController;
		
		[FlurryAnalytics logEvent:@"ServerType" withParameters:[NSDictionary dictionaryWithObject:@"Subsonic" forKey:@"type"]];
	}
	else if (sender == self.ubuntuButton)
	{
		UbuntuServerEditViewController *ubuntuServerEditViewController = [[UbuntuServerEditViewController alloc] initWithNibName:@"UbuntuServerEditViewController" bundle:nil];
		ubuntuServerEditViewController.parentController = self;
		ubuntuServerEditViewController.view.frame = self.view.bounds;
		ubuntuServerEditViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view addSubview:ubuntuServerEditViewController.view];
		self.serverEditViewController = ubuntuServerEditViewController;
		subView = ubuntuServerEditViewController.view;
		
		[FlurryAnalytics logEvent:@"ServerType" withParameters:[NSDictionary dictionaryWithObject:@"UbuntuOne" forKey:@"type"]];
	}
	else if (sender == self.cancelButton)
	{
		[self dismissModalViewControllerAnimated:YES];
		return;
	}
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.5];
	[UIView setAnimationTransition:UIViewAnimationTransitionFlipFromRight forView:self.view cache:YES];
	
	[self.view addSubview:subView];
	
	[UIView commitAnimations];
}

@end
