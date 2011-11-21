//
//  CurrentPlaylistBackgroundViewController.m
//  iSub
//
//  Created by Ben Baron on 4/9/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CurrentPlaylistBackgroundViewController.h"
#import "CurrentPlaylistViewController.h"
#import "iSubAppDelegate.h"

@implementation CurrentPlaylistBackgroundViewController

- (void)viewDidLoad 
{
	playlistView = [[CurrentPlaylistViewController alloc] initWithNibName:@"CurrentPlaylistViewController" bundle:nil];
	[self.view addSubview:playlistView.view];
		
    [super viewDidLoad];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[playlistView viewDidDisappear:NO];
	[playlistView release]; playlistView = nil;
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
