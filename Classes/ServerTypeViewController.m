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
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}

- (IBAction)buttonAction:(id)sender
{
	UIView *subView = nil;

	if (sender == subsonicButton)
	{
		SubsonicServerEditViewController *subsonicServerEditViewController = [[SubsonicServerEditViewController alloc] initWithNibName:@"SubsonicServerEditViewController" bundle:nil];
		subsonicServerEditViewController.parentController = self;
		subsonicServerEditViewController.view.frame = self.view.bounds;
		subsonicServerEditViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		subView = subsonicServerEditViewController.view;
	}
	else if (sender == ubuntuButton)
	{
		UbuntuServerEditViewController *ubuntuServerEditViewController = [[UbuntuServerEditViewController alloc] initWithNibName:@"UbuntuServerEditViewController" bundle:nil];
		ubuntuServerEditViewController.parentController = self;
		ubuntuServerEditViewController.view.frame = self.view.bounds;
		ubuntuServerEditViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[self.view addSubview:ubuntuServerEditViewController.view];
		subView = ubuntuServerEditViewController.view;
	}
	else if (sender == cancelButton)
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


- (void)dealloc {
    [super dealloc];
}


@end
