//
//  FolderViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "FolderViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "AlbumUITableViewCell.h"
#import "SongUITableViewCell.h"
#import "AllSongsUITableViewCell.h"
#import "ModalAlbumArtViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import <MediaPlayer/MediaPlayer.h>

@interface FolderViewController() <ISMSLoaderDelegate, AsynchronousImageViewDelegate>
{
    NSString *_folderId;
    ISMSArtist *_artist;
    ISMSAlbum *_album;
    BOOL _reloading;
    NSArray *_sectionInfo;
    SUSSubFolderDAO *_dataModel;
}
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
@end


@implementation FolderViewController

#pragma mark - Lifecycle -

- (FolderViewController *)initWithArtist:(ISMSArtist *)anArtist orAlbum:(ISMSAlbum *)anAlbum
{
	if (anArtist == nil && anAlbum == nil)
	{
		return nil;
	}
	
	self = [super initWithNibName:@"FolderViewController" bundle:nil];
	if (self != nil)
	{
		_sectionInfo = nil;
		
		if (anArtist != nil)
		{
			self.title = anArtist.name;
			_folderId = [anArtist.artistId copy];
			_artist = anArtist;
			_album = nil;
		}
		else
		{
			self.title = anAlbum.title;
			_folderId = [anAlbum.albumId copy];
			_artist = [ISMSArtist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
			_album = anAlbum;
		}
		
		_dataModel = [[SUSSubFolderDAO alloc] initWithDelegate:self andId:_folderId andArtist:_artist];
		
        if (_dataModel.hasLoaded)
        {
            [self.tableView reloadData];
            [self addHeaderAndIndex];
        }
        else
        {
            [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
            [_dataModel startLoad];
        }
	}
	
	return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
    
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;
	
	_albumInfoArtView.delegate = self;
	    
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(createReflection)
                                                 name:@"createReflection"
                                               object:nil];
}

- (void)viewWillAppear:(BOOL)animated 
{	
	[super viewWillAppear:animated];
	
	[self.tableView reloadData];
		
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData)
                                                 name:ISMSNotification_CurrentPlaylistIndexChanged
                                               object:nil];
    
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(reloadData)
                                                 name:ISMSNotification_SongPlaybackStarted
                                               object:nil];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[_dataModel cancelLoad];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_CurrentPlaylistIndexChanged object:nil];	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackStarted object:nil];	
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
	
	_albumInfoArtView.delegate = nil;
	_dataModel.delegate = nil;
}

#pragma mark - Loading -

- (void)reloadData
{
    [self.tableView reloadData];
}

- (BOOL)shouldSetupRefreshControl
{
    return YES;
}

- (void)didPullToRefresh
{
    if (!_reloading)
    {
        _reloading = YES;
        [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
        [_dataModel startLoad];
    }
}

- (void)dataSourceDidFinishLoadingNewData
{
    _reloading = NO;
    
    [self.refreshControl endRefreshing];
}

- (void)cancelLoad
{
	[_dataModel cancelLoad];
	[self dataSourceDidFinishLoadingNewData];
	[viewObjectsS hideLoadingScreen];
}

- (void)createReflection
{
	_albumInfoArtReflection.image = [_albumInfoArtView reflectedImageWithHeight:_albumInfoArtReflection.height];
}

- (void)asyncImageViewFinishedLoading:(AsynchronousImageView *)asyncImageView
{
	// Make sure to set the reflection again once the art loads
	[self createReflection];
}

- (void)addHeaderAndIndex
{
	if (_dataModel.songsCount == 0 && _dataModel.albumsCount == 0)
	{
		self.tableView.tableHeaderView = nil;
	}
	else if (_dataModel.songsCount > 0)
	{
		if (!self.tableView.tableHeaderView)
		{
			CGFloat headerHeight = _albumInfoView.height + _playAllShuffleAllView.height;
			CGRect headerFrame = CGRectMake(0., 0., 320, headerHeight);
			UIView *headerView = [[UIView alloc] initWithFrame:headerFrame];
			
			_albumInfoArtView.isLarge = YES;
			
			[headerView addSubview:_albumInfoView];
			
			_playAllShuffleAllView.y = _albumInfoView.height;
			[headerView addSubview:_playAllShuffleAllView];
			
			self.tableView.tableHeaderView = headerView;
		}
		
		if (!_album)
		{
			ISMSAlbum *anAlbum = [[ISMSAlbum alloc] init];
			ISMSSong *aSong = [_dataModel songForTableViewRow:_dataModel.albumsCount];
			anAlbum.title = aSong.album;
			anAlbum.artistName = aSong.artist;
			anAlbum.coverArtId = aSong.coverArtId;
			_album = anAlbum;
		}
		
		_albumInfoArtView.coverArtId = _album.coverArtId;
		_albumInfoArtistLabel.text = _album.artistName;
		_albumInfoAlbumLabel.text = _album.title;
		
		_albumInfoDurationLabel.text = [NSString formatTime:_dataModel.folderLength];
		_albumInfoTrackCountLabel.text = [NSString stringWithFormat:@"%ld Tracks", (long)_dataModel.songsCount];
		if (_dataModel.songsCount == 1)
			_albumInfoTrackCountLabel.text = [NSString stringWithFormat:@"%ld Track", (long)_dataModel.songsCount];
		
		// Create reflection
		[self createReflection];
		
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	}
	else
	{
		self.tableView.tableHeaderView = _playAllShuffleAllView;
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
	}
	
	_sectionInfo = _dataModel.sectionInfo;
	if (_sectionInfo)
		[self.tableView reloadData];
}

#pragma mark - Actions -

- (IBAction)a_expandCoverArt:(id)sender
{
	if(_album.coverArtId)
	{		
		ModalAlbumArtViewController *largeArt = nil;
		largeArt = [[ModalAlbumArtViewController alloc] initWithAlbum:_album
													   numberOfTracks:_dataModel.songsCount
														  albumLength:_dataModel.folderLength];
		if (IS_IPAD())
			[appDelegateS.ipadRootViewController presentViewController:largeArt animated:YES completion:nil];
		else
			[self presentViewController:largeArt animated:YES completion:nil];
	}
}

- (IBAction)a_playAll:(id)sender
{
	[databaseS playAllSongs:_folderId artist:_artist];
}

- (IBAction)a_shuffle:(id)sender
{
	[databaseS shuffleAllSongs:_folderId artist:_artist];
}

#pragma mark - Table View Delegate -

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
	NSMutableArray *indexes = [[NSMutableArray alloc] init];
	for (int i = 0; i < [_sectionInfo count]; i++)
	{
		[indexes addObject:[[_sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
	}
	return indexes;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	NSUInteger row = [[[_sectionInfo objectAtIndexSafe:index] objectAtIndexSafe:1] intValue];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
	[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	
	return -1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	return _dataModel.totalCount;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row < _dataModel.albumsCount)
	{
		static NSString *cellIdentifier = @"AlbumCell";
		AlbumUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[AlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		
        ISMSAlbum *anAlbum = [_dataModel albumForTableViewRow:indexPath.row];
        
        cell.myId = anAlbum.albumId;
		cell.myArtist = [ISMSArtist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
		if (_sectionInfo)
			cell.isIndexShowing = YES;
		
		cell.coverArtView.coverArtId = anAlbum.coverArtId;
		
		[cell.albumNameLabel setText:anAlbum.title];
        
		// Setup cell backgrond color
        cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
		return cell;
	}
	else
	{
		static NSString *cellIdentifier = @"SongCell";
		SongUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[SongUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryNone;
		}
		cell.indexPath = indexPath;
        
        ISMSSong *aSong = [_dataModel songForTableViewRow:indexPath.row];
        
		cell.mySong = aSong;
		
		if (aSong.isCurrentPlayingSong)
		{
			cell.nowPlayingImageView.hidden = NO;
			cell.trackNumberLabel.hidden = YES;
		}
		else 
		{
			cell.nowPlayingImageView.hidden = YES;
			cell.trackNumberLabel.hidden = NO;
			
			if ( [aSong.track intValue] != 0 )
				cell.trackNumberLabel.text = [NSString stringWithFormat:@"%i", [aSong.track intValue]];
			else
				cell.trackNumberLabel.text = @"";
		}
		
		cell.songNameLabel.text = aSong.title;
		
		if ( aSong.artist)
			cell.artistNameLabel.text = aSong.artist;
		else
			cell.artistNameLabel.text = @"";		
		
		if ( aSong.duration )
			cell.songDurationLabel.text = [NSString formatTime:[aSong.duration floatValue]];
		else
			cell.songDurationLabel.text = @"";
		
        if (aSong.isFullyCached)
        {
            cell.backgroundView = [[UIView alloc] init];
            cell.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
        }
        else
        {
            cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
        }
		
		return cell;
	}
}

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (indexPath.row < _dataModel.albumsCount)
		return 60.0;
	else
		return 50.0;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		if (indexPath.row < _dataModel.albumsCount)
		{
            ISMSAlbum *anAlbum = [_dataModel albumForTableViewRow:indexPath.row];
            			
			FolderViewController *albumViewController = [[FolderViewController alloc] initWithArtist:nil orAlbum:anAlbum];	
			[self pushViewControllerCustom:albumViewController];
		}
		else
		{
            ISMSSong *playedSong = [_dataModel playSongAtTableViewRow:indexPath.row];
            
            if (!playedSong.isVideo)
                [self showPlayer];
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark - ISMSLoader delegate -

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    // Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %li: %@", (long)[error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
	
	if (_dataModel.songsCount == 0 && _dataModel.albumsCount == 0)
		[self.tableView removeBottomShadow];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self addHeaderAndIndex];
	
	[self dataSourceDidFinishLoadingNewData];
}

@end

