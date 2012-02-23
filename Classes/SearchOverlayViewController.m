//
//  SearchOverlayViewController.m
//  iSub
//
//  Created by Ben Baron on 4/1/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SearchOverlayViewController.h"
#import "SavedSettings.h"
#import "NSNotificationCenter+MainThread.h"

@implementation SearchOverlayViewController

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)touchesBegan:(NSSet *)touches withEvent:(UIEvent *)event 
{	
	//iSubAppDelegate *appDelegate = (iSubAppDelegate*)[[UIApplication sharedApplication] delegate];
	//[appDelegateS.rootViewController doneSearching_Clicked:nil];
	//[(AllAlbumsViewController *) appDelegateS.allAlbumsNavigationController.topViewController doneSearching_Clicked:nil];
	//[(AllSongsViewController *) appDelegateS.allSongsNavigationController.topViewController doneSearching_Clicked:nil];
	[NSNotificationCenter postNotificationToMainThreadWithName:@"endSearch"];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)dealloc 
{
    [super dealloc];
}


@end
