//
//  NewHomeViewController.m
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NewHomeViewController.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "SearchXMLParser.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "QuickAlbumsViewController.h"
#import "ChatViewController.h"
#import "MGSplitViewController.h"
#import "SearchSongsViewController.h"
#import "NSString+rfcEncode.h"
#import "StoreViewController.h"
#import "CustomUIAlertView.h"
#import "AsynchronousImageView.h"
#import "Song.h"
#import "NSString+md5.h"
#import "NSString+TrimmingAdditions.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "ShuffleFolderPickerViewController.h"
#import "FolderPickerDialog.h"
#import "SearchAllViewController.h"
#import "NSString+TrimmingAdditions.h"
#import <QuartzCore/QuartzCore.h>
#import "SavedSettings.h"
#import "SUSRootFoldersDAO.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSString+URLEncode.h"
#import "NSMutableURLRequest+SUS.h"
#import "SUSCurrentPlaylistDAO.h"
#import "BassWrapperSingleton.h"

@implementation NewHomeViewController

@synthesize receivedData;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void) willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	//BOOL rotationDisabled = [[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"];
	BOOL rotationDisabled = [SavedSettings sharedInstance].isRotationLockEnabled;
	
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation) && !rotationDisabled)
	{
		if (!IS_IPAD())
		{
			// Animate the segmented control off screen
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:.3];
			[UIView setAnimationCurve:UIViewAnimationCurveLinear];
			quickLabel.alpha = 1.0;
			shuffleLabel.alpha = 1.0;
			jukeboxLabel.alpha = 1.0;
			settingsLabel.alpha = 1.0;
			chatLabel.alpha = 1.0;
			playerLabel.alpha = 1.0;
			
			coverArtBorder.alpha = 1.0;
			coverArtView.alpha = 1.0;
			artistLabel.alpha = 1.0;
			albumLabel.alpha = 1.0;
			songLabel.alpha = 1.0;
			[UIView commitAnimations];
		}
	}
	else if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation) && !rotationDisabled)
	{
		if (!IS_IPAD())
		{
			// Animate the segmented control off screen
			[UIView beginAnimations:nil context:NULL];
			[UIView setAnimationDuration:.3];
			[UIView setAnimationCurve:UIViewAnimationCurveLinear];
			quickLabel.alpha = 0.0;
			shuffleLabel.alpha = 0.0;
			jukeboxLabel.alpha = 0.0;
			settingsLabel.alpha = 0.0;
			chatLabel.alpha = 0.0;
			playerLabel.alpha = 0.0;
			
			coverArtBorder.alpha = 0.0;
			coverArtView.alpha = 0.0;
			artistLabel.alpha = 0.0;
			albumLabel.alpha = 0.0;
			songLabel.alpha = 0.0;
			[UIView commitAnimations];
		}
	}
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	
	searchSegment.selectedSegmentIndex = 3;
	
	self.title = @"Home";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settings)] autorelease];

	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(jukeboxOff) name:@"JukeboxTurnedOff" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(initSongInfo) name:ISMSNotification_SongPlaybackStart object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(performServerShuffle:) name:@"performServerShuffle" object:nil];

	if (!IS_IPAD())
	{
		//coverArtBorder = [[UIView alloc] initWithFrame:CGRectMake(15, 180, 290, 60)];
		coverArtBorder = [[UIButton buttonWithType:UIButtonTypeCustom] retain];
		coverArtBorder.frame = CGRectMake(15, 177, 290, 60);
		coverArtBorder.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
		coverArtBorder.layer.borderWidth = 2.0f;
		[coverArtBorder addTarget:self action:@selector(player) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:coverArtBorder];
		
		coverArtView = [[AsynchronousImageView alloc] init];
		//coverArtView.frame = CGRectMake(2, 2, 56, 56);
		coverArtView.frame = CGRectMake(0, 0, 60, 60);
		coverArtView.isForPlayer = YES;
		coverArtView.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
		coverArtView.layer.borderWidth = 2.0f;
		
		//[coverArtBorder addSubview:coverArtView];
		//[self.view addSubview:coverArtBorder];
		[coverArtBorder addSubview:coverArtView];
		
		artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 3, 220, 17)];
		artistLabel.backgroundColor = [UIColor clearColor];
		artistLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		artistLabel.font = [UIFont boldSystemFontOfSize:17];
		artistLabel.minimumFontSize = 12;
		artistLabel.adjustsFontSizeToFitWidth = YES;
		artistLabel.textAlignment = UITextAlignmentCenter;
		[coverArtBorder addSubview:artistLabel];
		
		albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 20, 220, 17)];
		albumLabel.backgroundColor = [UIColor clearColor];
		albumLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		albumLabel.font = [UIFont systemFontOfSize:17];
		albumLabel.minimumFontSize = 12;
		albumLabel.adjustsFontSizeToFitWidth = YES;
		albumLabel.textAlignment = UITextAlignmentCenter;
		[coverArtBorder addSubview:albumLabel];
		
		songLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 37, 220, 17)];
		songLabel.backgroundColor = [UIColor clearColor];
		songLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		songLabel.font = [UIFont boldSystemFontOfSize:17];
		songLabel.minimumFontSize = 12;
		songLabel.adjustsFontSizeToFitWidth = YES;
		songLabel.textAlignment = UITextAlignmentCenter;
		[coverArtBorder addSubview:songLabel];				
		
		[self initSongInfo];
	}	
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	viewObjects.isSettingsShowing = NO;
	
	//////////// Handle landscape bug
	//BOOL rotationDisabled = [[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"];
	BOOL rotationDisabled = [SavedSettings sharedInstance].isRotationLockEnabled;
	
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation) && !rotationDisabled)
	{
		if (!IS_IPAD())
		{
			quickLabel.alpha = 1.0;
			shuffleLabel.alpha = 1.0;
			jukeboxLabel.alpha = 1.0;
			settingsLabel.alpha = 1.0;
			chatLabel.alpha = 1.0;
			playerLabel.alpha = 1.0;
			
			coverArtBorder.alpha = 1.0;
			coverArtView.alpha = 1.0;
			artistLabel.alpha = 1.0;
			albumLabel.alpha = 1.0;
			songLabel.alpha = 1.0;
		}
	}
	else if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation) && !rotationDisabled)
	{
		if (!IS_IPAD())
		{
			quickLabel.alpha = 0.0;
			shuffleLabel.alpha = 0.0;
			jukeboxLabel.alpha = 0.0;
			settingsLabel.alpha = 0.0;
			chatLabel.alpha = 0.0;
			playerLabel.alpha = 0.0;
			
			coverArtBorder.alpha = 0.0;
			coverArtView.alpha = 0.0;
			artistLabel.alpha = 0.0;
			albumLabel.alpha = 0.0;
			songLabel.alpha = 0.0;
		}
	}
	////////////////
	
	/*if (UIInterfaceOrientationIsPortrait([UIDevice currentDevice].orientation))
	{
		if (!IS_IPAD())
			[[NSBundle mainBundle] loadNibNamed:@"NewHomeViewController" owner:self options:nil];
	}
	else if (UIInterfaceOrientationIsLandscape([UIDevice currentDevice].orientation))
	{
		if (!IS_IPAD())
			[[NSBundle mainBundle] loadNibNamed:@"NewHomeViewControllerLandscape" owner:self options:nil];
	}*/
	
	if(musicControls.showPlayerIcon)
	{
		playerButton.enabled = YES;
		playerButton.alpha = 1.0;
		//self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(player)] autorelease];
	}
	else
	{
		playerButton.enabled = NO;
		playerButton.alpha = 0.5;
		//self.navigationItem.rightBarButtonItem = nil;
	}
	
	if ([SavedSettings sharedInstance].isJukeboxEnabled)
	{
		if (IS_IPAD())
			[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-on-ipad.png"] forState:UIControlStateNormal];
		else
			[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-on.png"] forState:UIControlStateNormal];
	}
	else
	{
		if (IS_IPAD())
			[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off-ipad.png"] forState:UIControlStateNormal];
		else
			[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off.png"] forState:UIControlStateNormal];
	}
	
	searchSegment.alpha = 0.0;
	searchSegment.enabled = NO;
	searchSegmentBackground.alpha = 0.0;
	
	[appDelegate checkAPIVersion];
}

- (void)initSongInfo
{
	SUSCurrentPlaylistDAO *dataModel = [SUSCurrentPlaylistDAO dataModel];
	Song *currentSong = dataModel.currentSong;
	
	
	if (currentSong != nil)
	{		
		if(currentSong.coverArtId)
		{		
			FMDatabase *coverArtCache = databaseControls.coverArtCacheDb320;
			
			if ([coverArtCache intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [currentSong.coverArtId md5]] == 1)
			{
				NSData *imageData = [coverArtCache dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [currentSong.coverArtId md5]];
				if (SCREEN_SCALE() == 2.0)
				{
					UIGraphicsBeginImageContextWithOptions(CGSizeMake(320.0,320.0), NO, 2.0);
					[[UIImage imageWithData:imageData] drawInRect:CGRectMake(0,0,320,320)];
					coverArtView.image = UIGraphicsGetImageFromCurrentImageContext();
					UIGraphicsEndImageContext();
				}
				else
				{
					coverArtView.image = [UIImage imageWithData:imageData];
				}
			}
			else 
			{
				[coverArtView loadImageFromCoverArtId:currentSong.coverArtId isForPlayer:YES];
			}
		}
		else 
		{
			coverArtView.image = [UIImage imageNamed:@"default-album-art.png"];
		}
		
		artistLabel.text = @"";
		albumLabel.text = @"";
		songLabel.text = @"";
		
		if (currentSong.artist)
		{
			artistLabel.text = [[currentSong.artist copy] autorelease];
		}
		
		if (currentSong.album)
		{
			albumLabel.text = [[currentSong.album copy] autorelease];
		}
		
		if (currentSong.title)
		{
			songLabel.text = [[currentSong.title copy] autorelease];
		}
	}
	else
	{
		coverArtView.image = [UIImage imageNamed:@"default-album-art.png"];
		artistLabel.text = @"Use the Folders tab to find music";
		albumLabel.text = @"";
		songLabel.text = @"";
	}
}

- (IBAction)quickAlbums
{
	QuickAlbumsViewController *quickAlbums = [[QuickAlbumsViewController alloc] init];
	quickAlbums.parent = self;
	//quickAlbums.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	if ([quickAlbums respondsToSelector:@selector(setModalPresentationStyle:)])
		quickAlbums.modalPresentationStyle = UIModalPresentationFormSheet;
	
	if (IS_IPAD())
		[appDelegate.splitView presentModalViewController:quickAlbums animated:YES];
	else
		[self presentModalViewController:quickAlbums animated:YES];
}

- (void)pushViewController:(UIViewController *)viewController
{
	// Hide the loading screen
	[viewObjects hideLoadingScreen];
	
	// Push the view controller
	[self.navigationController pushViewController:viewController animated:YES];
}

- (IBAction)serverShuffle
{
	NSDictionary *folders = [SUSRootFoldersDAO folderDropdownFolders];
	
	/*NSString *key = [NSString stringWithFormat:@"folderDropdownCache%@", [appDelegate.defaultUrl md5]];
	NSData *archivedData = [appDelegate.settingsDictionary objectForKey:key];
	NSDictionary *folders = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];*/
	
	if (folders == nil || [folders count] == 2)
	{
		[self performServerShuffle:nil];
	}
	else
	{		
		float height = 65.0f;
		height += (float)[folders count] * 44.0f;
		
		if (height > 300.0f)
			height = 300.0f;
		
		FolderPickerDialog *blankDialog = [[FolderPickerDialog alloc] initWithFrame:CGRectMake(0, 0, 300, height)];
		blankDialog.titleLabel.text = @"Folder to Shuffle";
		[blankDialog show];
		[blankDialog release];
	}
}

- (void)performServerShuffle:(NSNotification*)notification 
{
	// Start the 100 record open search to create shuffle list
	isSearch = NO;
	NSDictionary *parameters = nil;
	if (notification == nil)
	{
        parameters = [NSDictionary dictionaryWithObject:@"100" forKey:@"size"];
	}
	else 
	{
		NSDictionary *userInfo = [notification userInfo];
		NSString *folderId = [NSString stringWithFormat:@"%i", [[userInfo objectForKey:@"folderId"] intValue]];
		
		if (folderId < 0)
            parameters = [NSDictionary dictionaryWithObject:@"100" forKey:@"size"];
		else
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"100", @"size", n2N(folderId), @"musicFolderId", nil];
	}

    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getRandomSongs" andParameters:parameters];
    
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		receivedData = [[NSMutableData data] retain];
		
		// Display the loading screen
		if (IS_IPAD())
			[viewObjects showAlbumLoadingScreen:appDelegate.splitView.view sender:self];
		else
			[viewObjects showAlbumLoadingScreen:appDelegate.currentTabBarController.view sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error creating the server shuffle list.\n\nThe connection could not be created" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 2;
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
}

- (void)cancelLoad
{
	[connection cancel];
	[viewObjects hideLoadingScreen];
}

- (IBAction)chat
{
	ChatViewController *chat = [[ChatViewController alloc] initWithNibName:@"ChatViewController" bundle:nil];
	//playlists.isHomeTab = YES;
	[self.navigationController pushViewController:chat animated:YES];
	[chat release];
}

- (IBAction)settings
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
	[serverListViewController release];
}

- (IBAction)player
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}

- (void)jukeboxOff
{
	if (IS_IPAD())
		[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off-ipad.png"] forState:UIControlStateNormal];
	else
		[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off.png"] forState:UIControlStateNormal];
}

- (IBAction)jukebox
{
	if ([SavedSettings sharedInstance].isJukeboxUnlocked)
	{
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
		{
			// Jukebox mode is on, turn it off
			if (IS_IPAD())
				[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off-ipad.png"] forState:UIControlStateNormal];
			else
				[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-off.png"] forState:UIControlStateNormal];
			[SavedSettings sharedInstance].isJukeboxEnabled = NO;
						
			appDelegate.window.backgroundColor = viewObjects.windowColor;
		}
		else
		{
            [[BassWrapperSingleton sharedInstance] stop];
			
			// Jukebox mode is off, turn it on
			if (IS_IPAD())
				[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-on-ipad.png"] forState:UIControlStateNormal];
			else
				[jukeboxButton setImage:[UIImage imageNamed:@"home-jukebox-on.png"] forState:UIControlStateNormal];
			[SavedSettings sharedInstance].isJukeboxEnabled = YES;
			
			[musicControls jukeboxGetInfo];
			
			appDelegate.window.backgroundColor = viewObjects.jukeboxColor;
		}	
	}
	else
	{
		StoreViewController *store = [[StoreViewController alloc] init];
		[self.navigationController pushViewController:store animated:YES];
		[store release];
	}
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"JukeboxTurnedOff" object:nil];
}


- (void)dealloc {
	[coverArtBorder release];
	[coverArtView release];
	[artistLabel release];
	[albumLabel release];
	[songLabel release];
    [super dealloc];
}

#pragma mark -
#pragma mark Search Bar Delgate

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar
{	
	//NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [appDelegate.defaultUrl md5]];
	
	// Create search overlay
	searchOverlay = [[UIView alloc] init];
	//if ([[appDelegate.settingsDictionary objectForKey:key] isEqualToString:@"YES"])
	if ([SavedSettings sharedInstance].isNewSearchAPI)
	{
		if (IS_IPAD())
			searchOverlay.frame = CGRectMake(0, 86, 1024, 1024);
		else
			searchOverlay.frame = CGRectMake(0, 82, 480, 480);
	}
	else
	{
		if (IS_IPAD())
			searchOverlay.frame = CGRectMake(0, 44, 1024, 1024);
		else
			searchOverlay.frame = CGRectMake(0, 44, 480, 480);
	}
	
	searchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	searchOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	searchOverlay.alpha = 0.0;
	[self.view addSubview:searchOverlay];
	[searchOverlay release];
		
	dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[dismissButton addTarget:searchBar action:@selector(resignFirstResponder) forControlEvents:UIControlEventTouchUpInside];
	dismissButton.frame = self.view.bounds;
	dismissButton.enabled = NO;
	[searchOverlay addSubview:dismissButton];
	
	// Animate the segmented control on screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.5];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	//if ([[appDelegate.settingsDictionary objectForKey:key] isEqualToString:@"YES"])
	if ([SavedSettings sharedInstance].isNewSearchAPI)
	{
		searchSegment.enabled = YES;
		searchSegment.alpha = 1;
		searchSegmentBackground.alpha = 1;
	}
	searchOverlay.alpha = 1;
	dismissButton.enabled = YES;
	[UIView commitAnimations];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar
{
	// Animate the segmented control off screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	//NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [appDelegate.defaultUrl md5]];
	//if ([[appDelegate.settingsDictionary objectForKey:key] isEqualToString:@"YES"])
	if ([SavedSettings sharedInstance].isNewSearchAPI)
	{
		searchSegment.alpha = 0;
		searchSegment.enabled = NO;
		searchSegmentBackground.alpha = 0;
	}
	searchOverlay.alpha = 0;
	dismissButton.enabled = NO;
	[UIView commitAnimations];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar
{
	isSearch = YES;
	
	[searchBar resignFirstResponder];
	
	NSString *searchTerms = [searchBar.text stringByTrimmingLeadingAndTrailingWhitespace];
	
    NSDictionary *parameters = nil;
    NSString *action = nil;
	if ([SavedSettings sharedInstance].isNewSearchAPI)
	{
        action = @"search2";
		NSString *searchTermsString = [NSString stringWithFormat:@"%@*", searchTerms];
		if (searchSegment.selectedSegmentIndex == 0)
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"artistCount", @"0", @"albumCount", @"0", @"songCount", 
                          n2N(searchTermsString), @"query", nil];
		}
		else if (searchSegment.selectedSegmentIndex == 1)
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"artistCount", @"20", @"albumCount", @"0", @"songCount", 
                          n2N(searchTermsString), @"query", nil];
		}
		else if (searchSegment.selectedSegmentIndex == 2)
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"0", @"artistCount", @"0", @"albumCount", @"20", @"songCount", 
                          n2N(searchTermsString), @"query", nil];
		}
		else
		{
            parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"artistCount", @"20", @"albumCount", @"20", @"songCount", 
                          n2N(searchTermsString), @"query", nil];
		}
	}
	else
	{
        action = @"search";
        parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"count", n2N(searchTerms), @"any", nil];
	}
		
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:action andParameters:parameters];
    
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		receivedData = [[NSMutableData data] retain];
		
		// Display the loading screen
		[viewObjects showLoadingScreenOnMainWindow];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error performing the search.\n\nThe connection could not be created" delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 2;
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
}

#pragma mark -
#pragma mark Connection delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message;
	if (isSearch)
	{
		message = [NSString stringWithFormat:@"There was an error completing the search.\n\nError:%@", error.localizedDescription];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error creating the server shuffle list.\n\nError:%@", error.localizedDescription];
	}
	
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	alert.tag = 2;
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[theConnection release];
	[receivedData release];
	
	[viewObjects hideLoadingScreen];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	if (isSearch)
	{
		// It's a search
		
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
		SearchXMLParser *parser = (SearchXMLParser*)[[SearchXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		/*NSString *key = [NSString stringWithFormat:@"isNewSearchAPI%@", [appDelegate.defaultUrl md5]];
		BOOL isNewSearchAPI = NO;
		if ([[appDelegate.settingsDictionary objectForKey:key] isEqualToString:@"YES"])
			isNewSearchAPI = YES;
		
		if (isNewSearchAPI && searchSegment.selectedSegmentIndex == 3)*/
		if ([SavedSettings sharedInstance].isNewSearchAPI && searchSegment.selectedSegmentIndex == 3)
		{
			SearchAllViewController *searchViewController = [[SearchAllViewController alloc] initWithNibName:@"SearchAllViewController" 
																						   bundle:nil];
			searchViewController.listOfArtists = [NSMutableArray arrayWithArray:parser.listOfArtists];
			searchViewController.listOfAlbums = [NSMutableArray arrayWithArray:parser.listOfAlbums];
			searchViewController.listOfSongs = [NSMutableArray arrayWithArray:parser.listOfSongs];
			
			searchViewController.query = [NSString stringWithFormat:@"%@*", searchBar.text];
			
			[xmlParser release];
			[parser release];
			
			[self.navigationController pushViewController:searchViewController animated:YES];
			
			[searchViewController release];
		}
		else
		{
			SearchSongsViewController *searchViewController = [[SearchSongsViewController alloc] initWithNibName:@"SearchSongsViewController" 
																										  bundle:nil];
			searchViewController.title = @"Search";
			//if (isNewSearchAPI)
			if ([SavedSettings sharedInstance].isNewSearchAPI)
			{
				if (searchSegment.selectedSegmentIndex == 0)
				{
					searchViewController.listOfArtists = [NSMutableArray arrayWithArray:parser.listOfArtists];
					//DLog(@"%@", searchViewController.listOfArtists);
				}
				else if (searchSegment.selectedSegmentIndex == 1)
				{
					searchViewController.listOfAlbums = [NSMutableArray arrayWithArray:parser.listOfAlbums];
					//DLog(@"%@", searchViewController.listOfAlbums);
				}
				else if (searchSegment.selectedSegmentIndex == 2)
				{
					searchViewController.listOfSongs = [NSMutableArray arrayWithArray:parser.listOfSongs];
					//DLog(@"%@", searchViewController.listOfSongs);
				}
				
				searchViewController.searchType = searchSegment.selectedSegmentIndex;
				searchViewController.query = [NSString stringWithFormat:@"%@*", searchBar.text];
			}
			else
			{
				searchViewController.listOfSongs = [NSMutableArray arrayWithArray:parser.listOfSongs];
				searchViewController.searchType = 2;
				searchViewController.query = searchBar.text;
			}
			
			[xmlParser release];
			[parser release];
			
			[self.navigationController pushViewController:searchViewController animated:YES];
			
			[searchViewController release];
		}
		
		// Hide the loading screen
		[viewObjects hideLoadingScreen];
	}
	else
	{
		// It's generating the 100 random songs list

		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
		SearchXMLParser *parser = (SearchXMLParser*)[[SearchXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
				
		[databaseControls resetCurrentPlaylistDb];
		for(Song *aSong in parser.listOfSongs)
		{
			[aSong addToPlaylistQueue];
			//[databaseControls insertSong:aSong intoTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		}
		
		if ([SavedSettings sharedInstance].isJukeboxEnabled)
			[musicControls jukeboxReplacePlaylistWithLocal];
		
		//musicControls.currentSongObject = [databaseControls songFromDbRow:0 inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		//musicControls.nextSongObject = [databaseControls songFromDbRow:1 inTable:@"currentPlaylist" inDatabase:databaseControls.currentPlaylistDb];
		
		musicControls.isShuffle = NO;
		
		// Hide the loading screen
		[viewObjects hideLoadingScreen];
		
		[musicControls playSongAtPosition:0];
		
		[xmlParser release];
		[parser release];
		
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
	
	[theConnection release];
	[receivedData release];
}


@end
