//
//  NewHomeViewController.h
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class AsynchronousImageView;

@interface NewHomeViewController : UIViewController

@property (strong) IBOutlet UIButton *playerButton;
@property (strong) IBOutlet UIButton *jukeboxButton;
@property (strong) IBOutlet UISearchBar *searchBar;
@property (strong) IBOutlet UISegmentedControl *searchSegment;
@property (strong) IBOutlet UIView *searchSegmentBackground;
@property (strong) UIView *searchOverlay;
@property (strong) UIButton *dismissButton;

@property BOOL isSearch;

@property (strong) IBOutlet UILabel *quickLabel;
@property (strong) IBOutlet UILabel *shuffleLabel;
@property (strong) IBOutlet UILabel *jukeboxLabel;
@property (strong) IBOutlet UILabel *settingsLabel;
@property (strong) IBOutlet UILabel *chatLabel;
@property (strong) IBOutlet UILabel *playerLabel;

@property (strong) UIButton *coverArtBorder;
@property (strong) AsynchronousImageView *coverArtView;
@property (strong) UILabel *artistLabel;
@property (strong) UILabel *albumLabel;
@property (strong) UILabel *songLabel;

@property (strong) NSURLConnection *connection;
@property (strong) NSMutableData *receivedData;

- (IBAction)quickAlbums;
- (IBAction)serverShuffle;
- (IBAction)settings;
- (IBAction)player;
- (IBAction)jukebox;
- (IBAction)chat;

- (IBAction)support:(id)sender;

- (void)initSongInfo;

- (void)performServerShuffle:(NSNotification*)notification;

- (void)cancelLoad;

@end
