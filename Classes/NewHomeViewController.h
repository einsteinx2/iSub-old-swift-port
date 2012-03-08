//
//  NewHomeViewController.h
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class AsynchronousImageView;

@interface NewHomeViewController : UIViewController
{
	
	IBOutlet UIButton *playerButton;
	IBOutlet UIButton *jukeboxButton;
	IBOutlet UISearchBar *searchBar;
	IBOutlet UISegmentedControl *searchSegment;
	IBOutlet UIView *searchSegmentBackground;
	UIView *searchOverlay;
	UIButton *dismissButton;
	
	BOOL isSearch;
	
	IBOutlet UILabel *quickLabel;
	IBOutlet UILabel *shuffleLabel;
	IBOutlet UILabel *jukeboxLabel;
	IBOutlet UILabel *settingsLabel;
	IBOutlet UILabel *chatLabel;
	IBOutlet UILabel *playerLabel;
	
	UIButton *coverArtBorder;
	AsynchronousImageView *coverArtView;
	UILabel *artistLabel;
	UILabel *albumLabel;
	UILabel *songLabel;
}

@property (retain) NSURLConnection *connection;
@property (retain) NSMutableData *receivedData;

- (IBAction)quickAlbums;
- (IBAction)serverShuffle;
- (IBAction)settings;
- (IBAction)player;
- (IBAction)jukebox;
- (IBAction)chat;

- (void)initSongInfo;

- (void)performServerShuffle:(NSNotification*)notification;

- (void)cancelLoad;

@end
