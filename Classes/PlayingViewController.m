//
//  PlayingViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "iSub-Swift.h"
#import "PlayingViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@interface PlayingViewController() <CustomUITableViewCellDelegate>
- (void)dataSourceDidFinishLoadingNewData;
@end

@implementation PlayingViewController

@synthesize nothingPlayingScreen, dataModel;
@synthesize reloading;
@synthesize isNothingPlayingScreenShowing, receivedData;

#pragma mark Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.isNothingPlayingScreenShowing = NO;
	
    self.tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
	
	self.title = @"Now Playing";
	
	self.dataModel = [[SUSNowPlayingDAO alloc] initWithDelegate:self];		
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
    	
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	
	[self.dataModel startLoad];
	
	[Flurry logEvent:@"NowPlayingTab"];
}

- (void)cancelLoad
{
	[self.dataModel cancelLoad];
	[viewObjectsS hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];
}

-(void)viewWillDisappear:(BOOL)animated
{
	if (self.isNothingPlayingScreenShowing)
	{
		[self.nothingPlayingScreen removeFromSuperview];
		self.isNothingPlayingScreenShowing = NO;
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

#pragma mark - CustomUITableViewController Overrides -

- (void)customizeTableView:(UITableView *)tableView
{
    tableView.rowHeight = ISMSNormalize(ISMSAlbumCellHeight + ISMSCellHeaderHeight);
}

#pragma mark - Table View Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.dataModel.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"PlayingCell";
    CustomUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell)
    {
        cell = [[CustomUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
        cell.selectionStyle = UITableViewCellSelectionStyleNone;
        cell.delegate = self;
    }
    
    NSUInteger index = (indexPath.row - 1) / 2;
    ISMSSong *aSong = [self.dataModel songForIndex:index];
    
    cell.associatedObject = aSong;
    
    // Set the cover art
    cell.coverArtId = aSong.coverArtId;
    
    // Create the background view
    cell.backgroundView = [viewObjectsS createCellBackground:index];
    
    // Set the header titles
    NSString *playTime = [self.dataModel playTimeForIndex:indexPath.row];
    NSString *username = [self.dataModel usernameForIndex:indexPath.row];
    NSString *playerName = [self.dataModel playerNameForIndex:indexPath.row];
    
    NSString *headerTitle = nil;
    if (playerName)
    {
        headerTitle = [NSString stringWithFormat:@"%@ @ %@ - %@", username, playerName, playTime];
    }
    else
    {
        headerTitle = [NSString stringWithFormat:@"%@ - %@", username, playTime];
    }
    cell.headerTitle = headerTitle;
    
    cell.title = aSong.title;
    cell.subTitle = aSong.albumName ? [NSString stringWithFormat:@"%@ - %@", aSong.artistName, aSong.albumName] : aSong.artistName;
    
    return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	if (!indexPath)
		return;
	
	ISMSSong *playedSong = [self.dataModel playSongAtIndex:indexPath.row];
	if (!playedSong.isVideo)
        [self showPlayer];
}

#pragma mark - ISMSLoader delegate

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    // Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the now playing list.\n\nError %li: %@", (long)[error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    [viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self dataSourceDidFinishLoadingNewData];
	
	// Display the no songs overlay if 0 results
	if (self.dataModel.count == 0)
	{
		if (!self.isNothingPlayingScreenShowing)
		{
			self.isNothingPlayingScreenShowing = YES;
			self.nothingPlayingScreen = [[UIImageView alloc] init];
			self.nothingPlayingScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
			self.nothingPlayingScreen.frame = CGRectMake(40, 100, 240, 180);
			self.nothingPlayingScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
			self.nothingPlayingScreen.image = [UIImage imageNamed:@"loading-screen-image"];
			self.nothingPlayingScreen.alpha = .80;
			
			UILabel *textLabel = [[UILabel alloc] init];
			textLabel.backgroundColor = [UIColor clearColor];
			textLabel.textColor = [UIColor whiteColor];
			textLabel.font = ISMSBoldFont(30);
			textLabel.textAlignment = NSTextAlignmentCenter;
			textLabel.numberOfLines = 0;
			[textLabel setText:@"Nothing Playing\non the\nServer"];
			textLabel.frame = CGRectMake(15, 15, 210, 150);
			[self.nothingPlayingScreen addSubview:textLabel];
			
			[self.view addSubview:self.nothingPlayingScreen];
			
		}
	}
	else
	{
		if (self.isNothingPlayingScreenShowing)
		{
			self.isNothingPlayingScreenShowing = NO;
			[self.nothingPlayingScreen removeFromSuperview];
		}
	}
}

#pragma mark - Pull to refresh methods

- (BOOL)shouldSetupRefreshControl
{
    return YES;
}

- (void)didPullToRefresh
{
	if (!self.reloading)
	{
		self.reloading = YES;
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
		[self.dataModel startLoad];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	self.reloading = NO;
	
    [self.refreshControl endRefreshing];
}

#pragma mark - CustomUITableViewCell Delegate -

- (void)tableCellDownloadButtonPressed:(CustomUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSSong class]])
    {
        [(ISMSSong *)cell.associatedObject addToCacheQueueDbQueue];
    }
    
    [cell.overlayView disableDownloadButton];
}

- (void)tableCellQueueButtonPressed:(CustomUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSSong class]])
    {
        [(ISMSSong *)cell.associatedObject addToCurrentPlaylistDbQueue];
    }
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
}

@end

