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

@property (nonatomic, strong) EGORefreshTableHeaderView *refreshHeaderView;
@property (nonatomic) BOOL isReloading;
@property (nonatomic, copy) NSString *myId;
@property (nonatomic, strong) Artist *myArtist;
@property (nonatomic, strong) Album *myAlbum;
@property (nonatomic, strong) NSArray *sectionInfo;
@property (nonatomic, strong) SUSSubFolderDAO *dataModel;
@property (nonatomic, strong) IBOutlet UIView *playAllShuffleAllView;
@property (nonatomic, strong) IBOutlet UIView *albumInfoView;
@property (nonatomic, strong) IBOutlet UIView *albumInfoArtHolderView;
@property (nonatomic, strong) IBOutlet AsynchronousImageView *albumInfoArtView;
@property (nonatomic, strong) IBOutlet UIImageView *albumInfoArtReflection;
@property (nonatomic, strong) IBOutlet UIView *albumInfoLabelHolderView;
@property (nonatomic, strong) IBOutlet UILabel *albumInfoArtistLabel;
@property (nonatomic, strong) IBOutlet UILabel *albumInfoAlbumLabel;
@property (nonatomic, strong) IBOutlet UILabel *albumInfoTrackCountLabel;
@property (nonatomic, strong) IBOutlet UILabel *albumInfoDurationLabel; 

- (AlbumViewController *)initWithArtist:(Artist *)anArtist orAlbum:(Album *)anAlbum;

- (void)cancelLoad;

- (IBAction)playAllAction:(id)sender;
- (IBAction)shuffleAction:(id)sender;
- (IBAction)expandCoverArt:(id)sender;

@end
