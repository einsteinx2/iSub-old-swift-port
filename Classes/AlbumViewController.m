//
//  AlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "AlbumViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "AlbumUITableViewCell.h"
#import "SongUITableViewCell.h"
#import "AllSongsUITableViewCell.h"
#import "AsynchronousImageView.h"
#import "Artist.h"
#import "Album.h"
#import "Song.h"
#import "NSString+md5.h"
#import "FMDatabaseAdditions.h"
#import "LoadingScreen.h"
#import "NSString+hex.h"
#import "AsynchronousImageView.h"
#import "EGORefreshTableHeaderView.h"
#import "ModalAlbumArtViewController.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSString+time.h"
#import "NSData+Base64.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSString+URLEncode.h"
#import "SUSSubFolderDAO.h"
#import "UIView+Tools.h"
#import "NSArray+Additions.h"
#import "UIImageView+Reflection.h"
#import "UIViewController+PushViewController.h"
#import "NSNotificationCenter+MainThread.h"

@interface AlbumViewController (Private)
- (void)dataSourceDidFinishLoadingNewData;
- (void)addHeaderAndIndex;
@end


@implementation AlbumViewController
@synthesize myId, myArtist, myAlbum;
@synthesize sectionInfo;
@synthesize dataModel;
@synthesize playAllShuffleAllView;
@synthesize albumInfoView, albumInfoArtHolderView, albumInfoArtView, albumInfoAlbumLabel, albumInfoArtistLabel, albumInfoDurationLabel, albumInfoLabelHolderView, albumInfoTrackCountLabel, albumInfoArtReflection;

@synthesize reloading=_reloading;

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

#pragma mark Lifecycle

- (AlbumViewController *)initWithArtist:(Artist *)anArtist orAlbum:(Album *)anAlbum
{
	if (anArtist == nil && anAlbum == nil)
	{
		return nil;
	}
	
	self = [super initWithNibName:@"AlbumViewController" bundle:nil];
	if (self != nil)
	{
		self.sectionInfo = nil;
		
		if (anArtist != nil)
		{
			self.title = anArtist.name;
			self.myId = anArtist.artistId;
			self.myArtist = anArtist;
			self.myAlbum = nil;
		}
		else
		{
			self.title = anAlbum.title;
			self.myId = anAlbum.albumId;
			self.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
			self.myAlbum = anAlbum;
		}
		
		self.dataModel = [[[SUSSubFolderDAO alloc] initWithDelegate:self andId:self.myId andArtist:self.myArtist] autorelease];
		
        if (dataModel.hasLoaded)
        {
            [self.tableView reloadData];
            [self addHeaderAndIndex];
        }
        else
        {
            [viewObjectsS showAlbumLoadingScreen:self.view sender:self];
            [dataModel startLoad];
        }
	}
	
	return self;
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	//else
	//{
		// Add the table fade
		UIImageView *fade = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
		fade.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
		fade.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.tableView.tableFooterView = fade;
	//}
	
	// Add the pull to refresh view
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[self.tableView addSubview:refreshHeaderView];
	[refreshHeaderView release];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(createReflection) name:@"createReflection"  object:nil];
	
}


-(void)viewWillAppear:(BOOL)animated 
{	
	[super viewWillAppear:animated];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	[self.tableView reloadData];
}

- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	[self.dataModel cancelLoad];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"createReflection" object:nil];
	
	[myId release]; myId = nil;
	[myArtist release]; myArtist = nil;
	[myAlbum release]; myAlbum = nil;
	
	[playAllShuffleAllView release]; playAllShuffleAllView = nil;
	[albumInfoView release]; albumInfoView = nil;
	[albumInfoArtHolderView release]; albumInfoArtHolderView = nil;
	[albumInfoArtView release]; albumInfoArtView = nil;
	[albumInfoLabelHolderView release]; albumInfoLabelHolderView = nil;
	[albumInfoArtistLabel release]; albumInfoArtistLabel = nil;
	[albumInfoAlbumLabel release]; albumInfoAlbumLabel = nil;
	[albumInfoTrackCountLabel release]; albumInfoTrackCountLabel = nil;
	[albumInfoDurationLabel release]; albumInfoDurationLabel = nil;
	
	dataModel.delegate = nil;
	[dataModel release]; dataModel = nil;
	[super dealloc];
}

#pragma mark Loading

- (void)cancelLoad
{
	[self.dataModel cancelLoad];
	[self dataSourceDidFinishLoadingNewData];
	[viewObjectsS hideLoadingScreen];
}

- (void)createReflection
{
	albumInfoArtReflection.image = [albumInfoArtView reflectedImageWithHeight:albumInfoArtReflection.height];
}

- (void)addHeaderAndIndex
{
	if (dataModel.songsCount == 0 && dataModel.albumsCount == 0)
	{
		self.tableView.tableHeaderView = nil;
	}
	else if (myAlbum)
	{
		if (IS_IPAD())
		{
			// Fix some sizes for the iPad
			CGFloat scaleFactor = 2.5;
			CGFloat borderSize = 5.;
			//albumInfoView.height = albumInfoView.height * scaleFactor;
			albumInfoView.size = CGSizeMake(self.view.width, albumInfoView.height * scaleFactor);
			albumInfoArtHolderView.width = albumInfoArtHolderView.width * scaleFactor + borderSize;
			albumInfoArtHolderView.height = albumInfoArtHolderView.height * scaleFactor + borderSize;
			albumInfoLabelHolderView.x = albumInfoArtHolderView.x + albumInfoArtHolderView.width + borderSize;
			// Set labels width to original header width, labels holder x, minus 20 point border
			albumInfoLabelHolderView.width = 320. - albumInfoLabelHolderView.x - borderSize;
			
			albumInfoArtistLabel.font = albumInfoAlbumLabel.font = [UIFont boldSystemFontOfSize:40];
			albumInfoArtistLabel.minimumFontSize = albumInfoAlbumLabel.minimumFontSize = 24;
			albumInfoDurationLabel.font = albumInfoTrackCountLabel.font = [UIFont systemFontOfSize:30];
		}
		
		CGFloat headerHeight = albumInfoView.height + playAllShuffleAllView.height;
		CGRect headerFrame = CGRectMake(0., 0., 320, headerHeight);
		UIView *headerView = [[UIView alloc] initWithFrame:headerFrame];
		//headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		
		albumInfoArtView.isLarge = YES;
		albumInfoArtView.coverArtId = myAlbum.coverArtId;
		
		albumInfoArtistLabel.text = myAlbum.artistName;
		albumInfoAlbumLabel.text = myAlbum.title;
		albumInfoDurationLabel.text = [NSString formatTime:dataModel.folderLength];
		
		albumInfoTrackCountLabel.text = [NSString stringWithFormat:@"%i Tracks", dataModel.songsCount];
		if (dataModel.songsCount == 1)
			albumInfoTrackCountLabel.text = [NSString stringWithFormat:@"%i Track", dataModel.songsCount];
		
		[headerView addSubview:albumInfoView];
		
		playAllShuffleAllView.y = albumInfoView.height;
		//playAllShuffleAllView.width = self.view.width;
		[headerView addSubview:playAllShuffleAllView];
		
		// Create reflection
		[self createReflection];
		
		self.tableView.tableHeaderView = headerView;
		[headerView release];
	}
	else
	{
		self.tableView.tableHeaderView = playAllShuffleAllView;
	}
	
	self.sectionInfo = dataModel.sectionInfo;
	if (sectionInfo)
		[self.tableView reloadData];
}

#pragma mark Actions

- (IBAction)expandCoverArt:(id)sender
{
	if(myAlbum.coverArtId)
	{		
		ModalAlbumArtViewController *largeArt = nil;
		largeArt = [[ModalAlbumArtViewController alloc] initWithAlbum:myAlbum 
													   numberOfTracks:dataModel.songsCount 
														  albumLength:dataModel.folderLength];
		if (IS_IPAD())
			[appDelegateS.ipadRootViewController presentModalViewController:largeArt animated:YES];
		else
			[self presentModalViewController:largeArt animated:YES];
		[largeArt release];
	}
}

- (IBAction)playAllAction:(id)sender
{
	[databaseS playAllSongs:myId artist:myArtist];
}

- (IBAction)shuffleAction:(id)sender
{
	[databaseS shuffleAllSongs:myId artist:myArtist];
}

- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}

#pragma mark Table view methods

// Following 2 methods handle the right side index
- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView 
{
	NSMutableArray *indexes = [[[NSMutableArray alloc] init] autorelease];
	for (int i = 0; i < [sectionInfo count]; i++)
	{
		[indexes addObject:[[sectionInfo objectAtIndexSafe:i] objectAtIndexSafe:0]];
	}
	return indexes;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	NSUInteger row = [[[sectionInfo objectAtIndexSafe:index] objectAtIndexSafe:1] intValue];
	NSIndexPath *indexPath = [NSIndexPath indexPathForRow:row inSection:0];
	[tableView scrollToRowAtIndexPath:indexPath atScrollPosition:UITableViewScrollPositionTop animated:NO];
	
	return -1;
}

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return dataModel.totalCount;
}

// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{		
	// Set up the cell...
	if (indexPath.row < dataModel.albumsCount)
	{
		static NSString *cellIdentifier = @"AlbumCell";
		AlbumUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[AlbumUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
			cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		}
		
        Album *anAlbum = [self.dataModel albumForTableViewRow:indexPath.row];
        
        cell.myId = anAlbum.albumId;
		cell.myArtist = [Artist artistWithName:anAlbum.artistName andArtistId:anAlbum.artistId];
		if (sectionInfo)
			cell.isIndexShowing = YES;
		
		cell.coverArtView.coverArtId = anAlbum.coverArtId;
		
		[cell.albumNameLabel setText:anAlbum.title];
				
		// Setup cell backgrond color
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
			cell.backgroundView.backgroundColor = viewObjectsS.lightNormal;
		else
			cell.backgroundView.backgroundColor = viewObjectsS.darkNormal;
		
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
        
        Song *aSong = [self.dataModel songForTableViewRow:indexPath.row];
		        
		cell.mySong = aSong;
		
		if ( [aSong.track intValue] != 0 )
			cell.trackNumberLabel.text = [NSString stringWithFormat:@"%i", [aSong.track intValue]];
		else
			cell.trackNumberLabel.text = @"";
		
		cell.songNameLabel.text = aSong.title;
		
		if ( aSong.artist)
			cell.artistNameLabel.text = aSong.artist;
		else
			cell.artistNameLabel.text = @"";		
		
		if ( aSong.duration )
			cell.songDurationLabel.text = [NSString formatTime:[aSong.duration floatValue]];
		else
			cell.songDurationLabel.text = @"";
		
		cell.backgroundView = [[[UIView alloc] init] autorelease];
		if(indexPath.row % 2 == 0)
		{
			if (aSong.isFullyCached)
				cell.backgroundView.backgroundColor = [viewObjectsS currentLightColor];
			else
				cell.backgroundView.backgroundColor = viewObjectsS.lightNormal;
		}
		else
		{
			if (aSong.isFullyCached)
				cell.backgroundView.backgroundColor = [viewObjectsS currentDarkColor];
			else
				cell.backgroundView.backgroundColor = viewObjectsS.darkNormal;
		}
		
		return cell;
	}
}

// Customize the height of individual rows to make the album rows taller to accomidate the album art.
- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.row < dataModel.albumsCount)
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
		if (indexPath.row < dataModel.albumsCount)
		{
            Album *anAlbum = [dataModel albumForTableViewRow:indexPath.row];
            			
			AlbumViewController *albumViewController = [[AlbumViewController alloc] initWithArtist:nil orAlbum:anAlbum];	
			[self pushViewController:albumViewController];
			[albumViewController release];
		}
		else
		{
			[self.dataModel playSongAtTableViewRow:indexPath.row];
			
			// Show the player
			if (IS_IPAD())
			{
				[NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_ShowPlayer];
			}
			else
			{
				iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
				streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
				[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
				[streamingPlayerViewController release];
			}
		}
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark - SUSLoader delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
    // Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the album.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
	
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self addHeaderAndIndex];
	
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging) 
	{
		if (refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView.contentOffset.y <= - 65.0f && !_reloading) 
	{
		_reloading = YES;
		[viewObjectsS showAlbumLoadingScreen:self.view sender:self];
		[dataModel startLoad];
		[refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	_reloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[refreshHeaderView setState:EGOOPullRefreshNormal];
}

@end

