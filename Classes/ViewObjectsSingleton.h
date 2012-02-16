//
//  ViewObjectsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@class iSubAppDelegate, RootViewController, Artist, LoadingScreen, Album, AlbumViewController, Server;


@interface ViewObjectsSingleton : NSObject <UITabBarControllerDelegate, UINavigationControllerDelegate>
{		
	iSubAppDelegate *appDelegate;
	
	// In App Purchase
	BOOL isPlaylistUnlocked;
	BOOL isJukeboxUnlocked;
	BOOL isCacheUnlocked;

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
	BOOL isArtistsLoading;
	
	// Albums page objects and variables
	//
	NSString *currentArtistId; //the id of the current artist so that it can be added to the album object (it's not returned with the xml response)
	NSString *currentArtistName; //the name of the current artist so that it can be added to the album object (it's not returned with the xml response)
	
	/*// All albums view objects
	//
	NSMutableArray *allAlbumsListOfAlbums; //array of album names for the current folder
	Album *allAlbumsAlbumObject;
	NSMutableArray *allAlbumsListOfSongs; //array of song names for the current folder
	NSString *allAlbumsCurrentArtistId;
	NSString *allAlbumsCurrentArtistName;
	LoadingScreen *allAlbumsLoadingScreen;
	NSInteger allAlbumsLoadingProgress;
	BOOL isAlbumsLoading;*/
	
	// Playlists view objects
	//
	NSMutableArray *listOfPlaylists;
	NSMutableArray *listOfPlaylistSongs;
	NSString *localPlaylist;
	NSMutableArray *listOfLocalPlaylists;
	BOOL isLocalPlaylist;

	// Settings page objects
	//
	//NSMutableArray *serverList;
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
	
	
	//BOOL isJukebox;
		
	NSString *currentLoadingFolderId;
	
	BOOL isSettingsShowing;
	
	BOOL isNoNetworkAlertShowing;
}

// XMLParser objects used to tell the parser how to parse
//
@property (retain) NSString *parseState;
@property (retain) NSString *allAlbumsParseState;
@property (retain) NSString *allSongsParseState;

// Home page objects
//
@property (retain) NSMutableArray *homeListOfAlbums;

// Artists page objects
//
//@property (retain) NSArray *artistIndex;
//@property (retain) NSArray *listOfArtists;
@property BOOL isArtistsLoading;

// Albums page objects and variables
//
@property (retain) NSString *currentArtistName;
@property (retain) NSString *currentArtistId;

/*// All albums view objects
//
@property (retain) NSMutableArray *allAlbumsListOfAlbums;
@property (retain) Album *allAlbumsAlbumObject;
@property (retain) NSMutableArray *allAlbumsListOfSongs;
@property (retain) NSString *allAlbumsCurrentArtistId;
@property (retain) NSString *allAlbumsCurrentArtistName;
@property (retain) LoadingScreen *allAlbumsLoadingScreen;
@property NSInteger allAlbumsLoadingProgress;
@property BOOL isAlbumsLoading;

// All songs view objects
//
@property BOOL isSongsLoading;*/

// Playlists view objects
//
@property (retain) NSMutableArray *listOfPlaylists;
@property (retain) NSMutableArray *listOfPlaylistSongs;
@property (retain) NSString *localPlaylist;
@property (retain) NSMutableArray *listOfLocalPlaylists;
@property BOOL isLocalPlaylist;

// Settings page objects
//
//@property (retain) NSMutableArray *serverList;
@property (retain) Server *serverToEdit;

// Chat page objects
//
@property (retain) NSMutableArray *chatMessages;

// New Stuff
@property BOOL isCellEnabled;
@property (retain) NSTimer *cellEnabledTimer;
@property (retain) NSMutableArray *queueAlbumListOfAlbums;
@property (retain) NSMutableArray *queueAlbumListOfSongs;
@property BOOL isEditing;
@property BOOL isEditing2;
@property (retain) NSMutableArray *multiDeleteList;
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

@property (retain) UIImage *deleteButtonImage;
@property (retain) UIImage *cacheButtonImage;
@property (retain) UIImage *queueButtonImage;


//@property BOOL isJukebox;

@property (retain) NSString *currentLoadingFolderId;

@property BOOL isSettingsShowing;

@property BOOL isNoNetworkAlertShowing;

@property BOOL isLoadingScreenShowing;

+ (ViewObjectsSingleton*)sharedInstance;

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
