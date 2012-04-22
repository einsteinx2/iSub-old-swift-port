//
//  ViewObjectsSingleton.h
//  iSub
//
//  Created by Ben Baron on 10/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#define viewObjectsS [ViewObjectsSingleton sharedInstance]

#import "MBProgressHUD.h"

@class FoldersViewController, Artist, LoadingScreen, Album, AlbumViewController, Server;

@interface ViewObjectsSingleton : NSObject <UITabBarControllerDelegate, UINavigationControllerDelegate, MBProgressHUDDelegate>
{		
	MBProgressHUD *HUD;
}

// XMLParser objects used to tell the parser how to parse
//
@property (copy) NSString *parseState;
@property (copy) NSString *allAlbumsParseState;
@property (copy) NSString *allSongsParseState;

// Home page objects
//
@property (strong) NSMutableArray *homeListOfAlbums;

// Artists page objects
//
@property BOOL isArtistsLoading;

// Albums page objects and variables
//
@property (copy) NSString *currentArtistName;
@property (copy) NSString *currentArtistId;

// Playlists view objects
//
@property (strong) NSMutableArray *listOfPlaylists;
@property (strong) NSMutableArray *listOfPlaylistSongs;
@property (copy) NSString *localPlaylist;
@property (strong) NSMutableArray *listOfLocalPlaylists;
@property BOOL isLocalPlaylist;

// Settings page objects
//
@property (strong) Server *serverToEdit;

// Chat page objects
//
@property (strong) NSMutableArray *chatMessages;

// New Stuff
@property BOOL isCellEnabled;
@property (strong) NSTimer *cellEnabledTimer;
@property (strong) NSMutableArray *queueAlbumListOfAlbums;
@property (strong) NSMutableArray *queueAlbumListOfSongs;
@property (strong) NSMutableArray *multiDeleteList;
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

@property (strong) UIImage *deleteButtonImage;
@property (strong) UIImage *cacheButtonImage;
@property (strong) UIImage *queueButtonImage;


//@property BOOL isJukebox;

@property (copy) NSString *currentLoadingFolderId;

@property BOOL isSettingsShowing;

@property BOOL isNoNetworkAlertShowing;

@property BOOL isLoadingScreenShowing;

+ (ViewObjectsSingleton*)sharedInstance;

- (void)orderMainTabBarController;

- (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message;
- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message;
- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender;
- (void)hideLoadingScreen;
- (UIColor *) currentLightColor;
- (UIColor *) currentDarkColor;

- (void)enableCells;

- (UIView *)createCellBackground:(NSUInteger)row;

@end
