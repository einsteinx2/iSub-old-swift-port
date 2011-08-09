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


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
	playlistView = [[CurrentPlaylistViewController alloc] initWithNibName:@"CurrentPlaylistViewController" bundle:nil];
	[self.view addSubview:playlistView.view];
		
    [super viewDidLoad];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
	[playlistView.view removeFromSuperview];
	[playlistView release]; playlistView = nil;
}


- (void)dealloc {
	NSLog(@"CurrentPlaylistBackgroundViewController dealloc called");
    [super dealloc];
}


@end
