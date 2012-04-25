//
//  AlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "AsynchronousImageViewDelegate.h"

@class Artist, Album, EGORefreshTableHeaderView, SUSSubFolderDAO, AsynchronousImageView;

@interface AlbumViewController : UITableViewController <SUSLoaderDelegate, AsynchronousImageViewDelegate>

@property (strong) EGORefreshTableHeaderView *refreshHeaderView;
@property BOOL reloading;
	
@property (copy) NSString *myId;
@property (strong) Artist *myArtist;
@property (strong) Album *myAlbum;

@property (strong) NSArray *sectionInfo;

@property (strong) SUSSubFolderDAO *dataModel;

@property (strong) IBOutlet UIView *playAllShuffleAllView;
@property (strong) IBOutlet UIView *albumInfoView;
@property (strong) IBOutlet UIView *albumInfoArtHolderView;
@property (strong) IBOutlet AsynchronousImageView *albumInfoArtView;
@property (strong) IBOutlet UIImageView *albumInfoArtReflection;
@property (strong) IBOutlet UIView *albumInfoLabelHolderView;
@property (strong) IBOutlet UILabel *albumInfoArtistLabel;
@property (strong) IBOutlet UILabel *albumInfoAlbumLabel;
@property (strong) IBOutlet UILabel *albumInfoTrackCountLabel;
@property (strong) IBOutlet UILabel *albumInfoDurationLabel; 

- (AlbumViewController *)initWithArtist:(Artist *)anArtist orAlbum:(Album *)anAlbum;

- (void)cancelLoad;

- (IBAction)playAllAction:(id)sender;
- (IBAction)shuffleAction:(id)sender;
- (IBAction)expandCoverArt:(id)sender;

@end
