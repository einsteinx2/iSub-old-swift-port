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
@property (retain) NSString *parseState;
@property (retain) NSString *allAlbumsParseState;
@property (retain) NSString *allSongsParseState;

// Home page objects
//
@property (retain) NSMutableArray *homeListOfAlbums;

// Artists page objects
//
@property BOOL isArtistsLoading;

// Albums page objects and variables
//
@property (retain) NSString *currentArtistName;
@property (retain) NSString *currentArtistId;

// Playlists view objects
//
@property (retain) NSMutableArray *listOfPlaylists;
@property (retain) NSMutableArray *listOfPlaylistSongs;
@property (retain) NSString *localPlaylist;
@property (retain) NSMutableArray *listOfLocalPlaylists;
@property BOOL isLocalPlaylist;

// Settings page objects
//
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

- (void)showLoadingScreenOnMainWindowWithMessage:(NSString *)message;
- (void)showLoadingScreen:(UIView *)view withMessage:(NSString *)message;
- (void)showAlbumLoadingScreen:(UIView *)view sender:(id)sender;
- (void)hideLoadingScreen;
- (UIColor *) currentLightColor;
- (UIColor *) currentDarkColor;

- (void)enableCells;

- (UIView *)createCellBackground:(NSUInteger)row;

@end
