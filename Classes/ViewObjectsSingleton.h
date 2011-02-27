//
//  ViewObjectsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class iSubAppDelegate, RootViewController, Artist, LoadingScreen, Album, AlbumViewController, Server;


@interface ViewObjectsSingleton : NSObject <UITabBarControllerDelegate, UINavigationControllerDelegate>
{		
	iSubAppDelegate *appDelegate;
	
	// In App Purchase
	BOOL isPlaylistUnlocked;
	BOOL isJukeboxUnlocked;
	BOOL isCacheUnlocked;
	
	// Constants
	UInt32 kHorizSwipeDragMin;
	UInt32 kVertSwipeDragMax;
	
	// XMLParser states, used to tell the parser how to parse
	//
	NSString *parseState;
	NSString *allAlbumsParseState;
	NSString *allSongsParseState;
		
	// Loading screen interface elements
	//
	UIView *loadingBackground;
	UIButton *inputBlocker;
	UIImageView *loadingScreen;
	UILabel *loadingLabel;
	UIActivityIndicatorView *activityIndicator;
	
	// Home page objects
	//
	NSMutableArray *homeListOfAlbums; //array of album names for the current folder
	
	// Artists page objects
	//
	NSArray *artistIndex;
	NSArray *listOfArtists;
	BOOL isArtistsLoading;
	
	// Albums page objects and variables
	//
	NSString *currentArtistId; //the id of the current artist so that it can be added to the album object (it's not returned with the xml response)
	NSString *currentArtistName; //the name of the current artist so that it can be added to the album object (it's not returned with the xml response)
	
	// All albums view objects
	//
	NSMutableArray *allAlbumsListOfAlbums; //array of album names for the current folder
	Album *allAlbumsAlbumObject;
	NSMutableArray *allAlbumsListOfSongs; //array of song names for the current folder
	NSString *allAlbumsCurrentArtistId;
	NSString *allAlbumsCurrentArtistName;
	LoadingScreen *allAlbumsLoadingScreen;
	NSInteger allAlbumsLoadingProgress;
	BOOL isSearchingAllAlbums;
	BOOL isAlbumsLoading;
	
	// All songs view objects
	//
	NSMutableArray *allSongsListOfAlbums;
	NSMutableArray *allSongsListOfSongs;
	NSString *allSongsCurrentArtistId;
	NSString *allSongsCurrentArtistName;
	NSString *allSongsCurrentAlbumId;
	NSString *allSongsCurrentAlbumName;
	NSInteger allSongsCount;
	LoadingScreen *allSongsLoadingScreen;
	NSInteger allSongsLoadingProgress;
	BOOL isSearchingAllSongs;
	BOOL isSongsLoading;
	
	
	// Playlists view objects
	//
	NSMutableArray *listOfPlaylists;
	NSMutableArray *listOfPlaylistSongs;
	NSArray *subsonicPlaylist;
	NSString *localPlaylist;
	NSMutableArray *listOfLocalPlaylists;
	BOOL isLocalPlaylist;
	
	
	// Playing view objects
	//
	NSMutableArray *listOfPlayingSongs;
	
	
	// Settings page objects
	//
	NSMutableArray *serverList;
	Server *serverToEdit;
	
	
	// Chat page objects
	//
	NSMutableArray *chatList;
	
	// New stuff
	BOOL isCellEnabled;
	NSTimer *cellEnabledTimer;
	NSMutableArray *queueAlbumListOfAlbums;
	NSMutableArray *queueAlbumListOfSongs;
	BOOL isEditing;
	BOOL isEditing2;
	NSMutableArray *multiDeleteList;
	BOOL isOfflineMode;
	BOOL isOnlineModeAlertShowing;
	BOOL cancelLoading;	
	
	// Cell colors
	//
	UIColor *lightRed;
	UIColor *darkRed;
	UIColor *lightYellow;
	UIColor *darkYellow;
	UIColor *lightGreen;
	UIColor *darkGreen;
	UIColor *lightBlue;
	UIColor *darkBlue;
	UIColor *lightNormal;
	UIColor *darkNormal;
	UIColor *windowColor;
	UIColor *jukeboxColor;
	
	UIImage *deleteButtonImage;
	UIImage *cacheButtonImage;
	UIImage *queueButtonImage;
	
	
	BOOL isJukebox;
	
	BOOL isNewSearchAPI;
	
	NSString *currentLoadingFolderId;
	
	BOOL isSettingsShowing;
}

// In App Purchase
//
@property (readonly) BOOL isPlaylistUnlocked;
@property (readonly) BOOL isJukeboxUnlocked;
@property (readonly) BOOL isCacheUnlocked;

// Constants
//
@property (readonly) UInt32 kHorizSwipeDragMin;
@property (readonly) UInt32 kVertSwipeDragMax;

// XMLParser objects used to tell the parser how to parse
//
@property (nonatomic, retain) NSString *parseState;
@property (nonatomic, retain) NSString *allAlbumsParseState;
@property (nonatomic, retain) NSString *allSongsParseState;

// Home page objects
//
@property (nonatomic, retain) NSMutableArray *homeListOfAlbums;

// Artists page objects
//
@property (nonatomic, retain) NSArray *artistIndex;
@property (nonatomic, retain) NSArray *listOfArtists;
@property BOOL isArtistsLoading;

// Albums page objects and variables
//
@property (nonatomic, retain) NSString *currentArtistName;
@property (nonatomic, retain) NSString *currentArtistId;

// All albums view objects
//
@property (nonatomic, retain) NSMutableArray *allAlbumsListOfAlbums;
@property (nonatomic, retain) Album *allAlbumsAlbumObject;
@property (nonatomic, retain) NSMutableArray *allAlbumsListOfSongs;
@property (nonatomic, retain) NSString *allAlbumsCurrentArtistId;
@property (nonatomic, retain) NSString *allAlbumsCurrentArtistName;
@property (nonatomic, retain) LoadingScreen *allAlbumsLoadingScreen;
@property NSInteger allAlbumsLoadingProgress;
@property BOOL isSearchingAllAlbums;
@property BOOL isAlbumsLoading;

// All songs view objects
//
@property (nonatomic, retain) NSMutableArray *allSongsListOfAlbums;
@property (nonatomic, retain) NSMutableArray *allSongsListOfSongs;
@property (nonatomic, retain) NSString *allSongsCurrentAlbumId;
@property (nonatomic, retain) NSString *allSongsCurrentAlbumName;
@property (nonatomic, retain) NSString *allSongsCurrentArtistId;
@property (nonatomic, retain) NSString *allSongsCurrentArtistName;
@property NSInteger allSongsCount;
@property (nonatomic, retain) LoadingScreen *allSongsLoadingScreen;
@property NSInteger allSongsLoadingProgress;
@property BOOL isSearchingAllSongs;
@property BOOL isSongsLoading;

// Playlists view objects
//
@property (nonatomic, retain) NSMutableArray *listOfPlaylists;
@property (nonatomic, retain) NSMutableArray *listOfPlaylistSongs;
@property (nonatomic, retain) NSArray *subsonicPlaylist;
@property (nonatomic, retain) NSString *localPlaylist;
@property (nonatomic, retain) NSMutableArray *listOfLocalPlaylists;
@property BOOL isLocalPlaylist;

// Playing view objects
//
@property (nonatomic, retain) NSMutableArray *listOfPlayingSongs;

// Settings page objects
//
@property (nonatomic, retain) NSMutableArray *serverList;
@property (nonatomic, retain) Server *serverToEdit;

// Chat page objects
//
@property (nonatomic, retain) NSMutableArray *chatMessages;

// New Stuff
@property BOOL isCellEnabled;
@property (nonatomic, retain) NSTimer *cellEnabledTimer;
@property (nonatomic, retain) NSMutableArray *queueAlbumListOfAlbums;
@property (nonatomic, retain) NSMutableArray *queueAlbumListOfSongs;
@property BOOL isEditing;
@property BOOL isEditing2;
@property (nonatomic, retain) NSMutableArray *multiDeleteList;
@property BOOL isOfflineMode;
@property BOOL isOnlineModeAlertShowing;
@property BOOL cancelLoading;

// Cell colors
//
@property (readonly) UIColor *lightRed;
@property (readonly) UIColor *darkRed;
@property (readonly) UIColor *lightYellow;
@property (readonly) UIColor *darkYellow;
@property (readonly) UIColor *lightGreen;
@property (readonly) UIColor *darkGreen;
@property (readonly) UIColor *lightBlue;
@property (readonly) UIColor *darkBlue;
@property (readonly) UIColor *lightNormal;
@property (readonly) UIColor *darkNormal;
@property (readonly) UIColor *windowColor;
@property (readonly) UIColor *jukeboxColor;

@property (nonatomic, retain) UIImage *deleteButtonImage;
@property (nonatomic, retain) UIImage *cacheButtonImage;
@property (nonatomic, retain) UIImage *queueButtonImage;


@property BOOL isJukebox;
@property BOOL isNewSearchAPI;

@property (nonatomic, retain) NSString *currentLoadingFolderId;

@property BOOL isSettingsShowing;

+ (ViewObjectsSingleton*)sharedInstance;

- (void)loadArtistList;

- (void)orderMainTabBarController;

- (void)showLoadingScreenOnMainWindow;
- (void)showLoadingScreen:(UIView *)view blockInput:(BOOL)blockInput mainWindow:(BOOL)mainWindow;
- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender;
- (void)hideLoadingScreen;
- (UIColor *) currentLightColor;
- (UIColor *) currentDarkColor;

- (void)enableCells;

- (UIView *)createCellBackground:(NSUInteger)row;

@end
