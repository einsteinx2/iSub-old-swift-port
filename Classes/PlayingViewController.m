//
//  PlayingViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlayingViewController.h"
#import "PlayingUITableViewCell.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"

@interface PlayingViewController (Private)
- (void)dataSourceDidFinishLoadingNewData;
@end

@implementation PlayingViewController

@synthesize nothingPlayingScreen, dataModel;
@synthesize reloading;
@synthesize isNothingPlayingScreenShowing, receivedData;

#pragma mark - Rotation Handling

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.isNothingPlayingScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Now Playing";
	
	self.dataModel = [[SUSNowPlayingDAO alloc] initWithDelegate:self];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
		
	if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
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


#pragma mark - Table View Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return self.dataModel.count;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"PlayingCell";
	PlayingUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[PlayingUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}
	
	ISMSSong *aSong = [self.dataModel songForIndex:indexPath.row];
	cell.mySong = aSong;
	
	// Set the cover art
	cell.coverArtView.coverArtId = aSong.coverArtId;
	
	// Create the background view
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	
	// Set the title label
	NSString *playTime = [self.dataModel playTimeForIndex:indexPath.row];
	NSString *username = [self.dataModel usernameForIndex:indexPath.row];
	NSString *playerName = [self.dataModel playerNameForIndex:indexPath.row];
	
	if (playerName)
	{
		NSString *text = [NSString stringWithFormat:@"%@ @ %@ - %@", username, playerName, playTime];
		[cell.userNameLabel setText:text];
	}
	else
	{
		NSString *text = [NSString stringWithFormat:@"%@ - %@", username, playTime];
		[cell.userNameLabel setText:text];
	}

	// Set the song name label
	cell.songNameLabel.text = aSong.title;
	if (aSong.album)
		cell.artistNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album];
	else
		cell.artistNameLabel.text = aSong.artist;
	
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
			self.nothingPlayingScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
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

@end

