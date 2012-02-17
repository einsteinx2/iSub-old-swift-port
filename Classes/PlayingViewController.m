//
//  PlayingViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PlayingViewController.h"
#import "PlayingUITableViewCell.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AsynchronousImageViewCached.h"
#import "Song.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "MGSplitViewController.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"
#import "FlurryAnalytics.h"
#import "SUSNowPlayingDAO.h"

@implementation PlayingViewController

@synthesize nothingPlayingScreen, dataModel;

#pragma mark - Rotation Handling

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

#pragma mark Lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	
	isNothingPlayingScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Now Playing";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];

	// Add the table fade
	UIImageView *fadeTop = [[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-top.png"]];
	fadeTop.frame =CGRectMake(0, -10, self.tableView.bounds.size.width, 10);
	fadeTop.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.tableView addSubview:fadeTop];
	[fadeTop release];
	
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
	
	self.dataModel = [[SUSNowPlayingDAO alloc] initWithDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
	if(musicControls.showPlayerIcon)
	{
		UIImage *playingImage = [UIImage imageNamed:@"now-playing.png"];
		UIBarButtonItem *buttonItem = [[UIBarButtonItem alloc] initWithImage:playingImage
																	   style:UIBarButtonItemStyleBordered 
																	  target:self 
																	  action:@selector(nowPlayingAction:)];
		self.navigationItem.rightBarButtonItem = [buttonItem autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	[viewObjects showLoadingScreenOnMainWindowWithMessage:nil];
	
	[dataModel startLoad];
		
	[FlurryAnalytics logEvent:@"NowPlayingTab"];
}

-(void)viewWillDisappear:(BOOL)animated
{
	if (isNothingPlayingScreenShowing == YES)
	{
		[nothingPlayingScreen removeFromSuperview];
		isNothingPlayingScreenShowing = NO;
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
    [super dealloc];
}

#pragma mark - Button Handling

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverVC = [[ServerListViewController alloc] 
										  initWithNibName:@"ServerListViewController" 
												   bundle:nil];
	serverVC.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverVC animated:YES];
	[serverVC release];
}


- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *playerVC = [[iPhoneStreamingPlayerViewController alloc]
													 initWithNibName:@"iPhoneStreamingPlayerViewController"
															  bundle:nil];
	playerVC.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:playerVC animated:YES];
	[playerVC release];
}


#pragma mark - Table View Delegate

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return dataModel.count;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
	Song *aSong = [dataModel songForIndex:indexPath.row];
	
	// Create the cell
	PlayingUITableViewCell *cell = [[PlayingUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault 
																 reuseIdentifier:CellIdentifier];
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	cell.mySong = aSong;
	
	// Set the cover art
	[cell.coverArtView loadImageFromCoverArtId:aSong.coverArtId];
	
	// Create the background view
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
		cell.backgroundView.backgroundColor = viewObjects.lightNormal;
	else
		cell.backgroundView.backgroundColor = viewObjects.darkNormal;
	
	// Set the title label
	NSString *playTime = [dataModel playTimeForIndex:indexPath.row];
	NSString *username = [dataModel usernameForIndex:indexPath.row];
	NSString *playerName = [dataModel playerNameForIndex:indexPath.row];
	
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
	[cell.songNameLabel setText:aSong.title];
	if (aSong.album)
		[cell.artistNameLabel setText:[NSString stringWithFormat:@"%@ - %@", aSong.artist, aSong.album]];
	else
		[cell.artistNameLabel setText:aSong.artist];
	
    return [cell autorelease];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	[dataModel playSongAtIndex:indexPath.row];
	
	// Show the player
	if (IS_IPAD())
	{
		[[NSNotificationCenter defaultCenter] postNotificationName:@"showPlayer" object:nil];
	}
	else
	{
		iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
		[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
		[streamingPlayerViewController release];
	}
}

#pragma mark - SUSLoader delegate

- (void)loadingFailed:(SUSLoader *)theLoader withError:(NSError *)error
{
    // Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the now playing list.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	[alert release];
	
	[viewObjects hideLoadingScreen];
}

- (void)loadingFinished:(SUSLoader *)theLoader
{
    [viewObjects hideLoadingScreen];
	
	[self.tableView reloadData];
	
	// Display the no songs overlay if 0 results
	if (dataModel.count == 0)
	{
		if (isNothingPlayingScreenShowing == NO)
		{
			isNothingPlayingScreenShowing = YES;
			nothingPlayingScreen = [[UIImageView alloc] init];
			nothingPlayingScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleTopMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleBottomMargin;
			nothingPlayingScreen.frame = CGRectMake(40, 100, 240, 180);
			nothingPlayingScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
			nothingPlayingScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
			nothingPlayingScreen.alpha = .80;
			
			UILabel *textLabel = [[UILabel alloc] init];
			textLabel.backgroundColor = [UIColor clearColor];
			textLabel.textColor = [UIColor whiteColor];
			textLabel.font = [UIFont boldSystemFontOfSize:32];
			textLabel.textAlignment = UITextAlignmentCenter;
			textLabel.numberOfLines = 0;
			[textLabel setText:@"Nothing Playing\non the\nServer"];
			textLabel.frame = CGRectMake(15, 15, 210, 150);
			[nothingPlayingScreen addSubview:textLabel];
			[textLabel release];
			
			[self.view addSubview:nothingPlayingScreen];
			
			[nothingPlayingScreen release];
		}
	}
}

@end

