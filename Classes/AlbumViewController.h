//
//  AlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, Artist, Album, EGORefreshTableHeaderView, SUSSubFolderDAO, AsynchronousImageView;

@interface AlbumViewController : UITableViewController <SUSLoaderDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	NSURLConnection *connection;
	NSMutableData *loadingData;
	
	NSString *myId;
	Artist *myArtist;
	Album *myAlbum;
	
	NSArray *sectionInfo;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
}

@property(assign,getter=isReloading) BOOL reloading;
	
@property (retain) NSString *myId;
@property (retain) Artist *myArtist;
@property (retain) Album *myAlbum;

@property (retain) NSArray *sectionInfo;

@property (retain) SUSSubFolderDAO *dataModel;

@property (retain) IBOutlet UIView *playAllShuffleAllView;
@property (retain) IBOutlet UIView *albumInfoView;
@property (retain) IBOutlet UIView *albumInfoArtHolderView;
@property (retain) IBOutlet AsynchronousImageView *albumInfoArtView;
@property (retain) IBOutlet UIImageView *albumInfoArtReflection;
@property (retain) IBOutlet UIView *albumInfoLabelHolderView;
@property (retain) IBOutlet UILabel *albumInfoArtistLabel;
@property (retain) IBOutlet UILabel *albumInfoAlbumLabel;
@property (retain) IBOutlet UILabel *albumInfoTrackCountLabel;
@property (retain) IBOutlet UILabel *albumInfoDurationLabel; 

- (AlbumViewController *)initWithArtist:(Artist *)anArtist orAlbum:(Album *)anAlbum;

- (void)cancelLoad;

- (IBAction)playAllAction:(id)sender;
- (IBAction)shuffleAction:(id)sender;
- (IBAction)expandCoverArt:(id)sender;

@end
