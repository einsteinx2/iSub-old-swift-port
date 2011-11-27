//
//  ServerListViewController.m
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ServerListViewController.h"
#import "SubsonicServerEditViewController.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseSingleton.h"
#import "SettingsTabViewController.h"
#import "HelpTabViewController.h"
#import "RootViewController.h"
#import "Server.h"
#import "ServerTypeViewController.h"
#import "UbuntuServerEditViewController.h"
#import "UIView+tools.h"
#import "CustomUIAlertView.h"
#import "Reachability.h"
#import "SavedSettings.h"
#import "BassWrapperSingleton.h"

@implementation ServerListViewController

@synthesize theNewRedirectionUrl;

-(BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
	
	viewObjects.isSettingsShowing = YES;
}

/* DOESN'T GET CALLED, setting isSettingShowing to NO in NewHomeViewController viewWillAppear instead
- (void)viewWillDisappear:(BOOL)animated
{
	[super viewWillDisappear:animated];
	
	viewObjects.isSettingsShowing = NO;
}*/

- (void)viewDidLoad 
{
    [super viewDidLoad];

    appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	databaseControls = [DatabaseSingleton sharedInstance];
	settings = [SavedSettings sharedInstance];
	
	theNewRedirectionUrl = nil;
	
	self.tableView.allowsSelectionDuringEditing = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"reloadServerList" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showSaveButton) name:@"showSaveButton" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(switchServer:) name:@"switchServer" object:nil];
	
	//viewObjects.tempServerList = [[NSMutableArray arrayWithArray:viewObjects.serverList] retain];
	//DLog(@"tempServerList: %@", viewObjects.tempServerList);
	
	self.title = @"Servers";
	if(self != [[self.navigationController viewControllers] objectAtIndex:0])
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(saveAction:)] autorelease];
	self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	if (settings.serverList == nil || [settings.serverList count] == 0)
		[self addAction:nil];
	
	// Setup segmented control in the header view
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 40)] autorelease];
	headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	
	segmentedControl = [[UISegmentedControl alloc] initWithItems:[NSArray arrayWithObjects:@"Servers", @"Settings", @"Help", nil]];
	segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	segmentedControl.segmentedControlStyle = UISegmentedControlStyleBar;
	segmentedControl.frame = CGRectMake(5, 2, 310, 36);
	segmentedControl.tintColor = [UIColor colorWithWhite:.57 alpha:1];
	segmentedControl.selectedSegmentIndex = 0;
	[headerView addSubview:segmentedControl];
	
	self.tableView.tableHeaderView = headerView;
	
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
}


- (void)reloadTable
{
	[self.tableView reloadData];
}


- (void)showSaveButton
{
	if(!isEditing)
	{
		if(self != [[self.navigationController viewControllers] objectAtIndex:0])
			self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStyleBordered target:self action:@selector(saveAction:)] autorelease];
		
	}
}


- (void)segmentAction:(id)sender
{
	if (segmentedControl.selectedSegmentIndex == 0)
	{
		self.tableView.scrollEnabled = YES;
		self.navigationItem.rightBarButtonItem = self.editButtonItem;
		
		UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
		fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
		fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.tableView.tableFooterView = fadeBottom;
		
		[self.tableView reloadData];
	}
	else if (segmentedControl.selectedSegmentIndex == 1)
	{
		self.tableView.scrollEnabled = YES;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		SettingsTabViewController *settingsTabViewController = [[SettingsTabViewController alloc] initWithNibName:@"SettingsTabViewController" bundle:nil];
		settingsTabViewController.parentController = self;
		self.tableView.tableFooterView = settingsTabViewController.view;
		//[settingsTabViewController release];
		[self.tableView reloadData];
	}
	else if (segmentedControl.selectedSegmentIndex == 2)
	{
		self.tableView.scrollEnabled = NO;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		HelpTabViewController *helpTabViewController = [[HelpTabViewController alloc] initWithNibName:@"HelpTabViewController" bundle:nil];
		if (IS_IPAD())
		{
			helpTabViewController.view.frame = self.view.bounds;
			[helpTabViewController.view addHeight:-40];
		}
		self.tableView.tableFooterView = helpTabViewController.view;
		[helpTabViewController release];
		[self.tableView reloadData];
	}
}


- (void)setEditing:(BOOL)editing animated:(BOOL)animate
{
    [super setEditing:editing animated:animate];
    if(editing)
    {
		isEditing = YES;
		self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAction:)] autorelease];
    }
    else
    {
		isEditing = NO;
		[self showSaveButton];
    }
}

- (void)addAction:(id)sender
{
	viewObjects.serverToEdit = nil;
	
	ServerTypeViewController *serverTypeViewController = [[ServerTypeViewController alloc] initWithNibName:@"ServerTypeViewController" bundle:nil];
	if ([serverTypeViewController respondsToSelector:@selector(setModalPresentationStyle:)])
		serverTypeViewController.modalPresentationStyle = UIModalPresentationFormSheet;
	if (IS_IPAD())
		[appDelegate.splitView presentModalViewController:serverTypeViewController animated:YES];
	else
		[self presentModalViewController:serverTypeViewController animated:YES];
	[serverTypeViewController release];
}

- (void)saveAction:(id)sender
{
	[self.navigationController popToRootViewControllerAnimated:YES];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
	//DLog(@"server list view controller view did unload");
}

- (void)showServerEditScreen
{
	if (viewObjects.serverToEdit.type == UBUNTU_ONE)
	{
		UbuntuServerEditViewController *ubuntuServerEditViewController = [[UbuntuServerEditViewController alloc] initWithNibName:@"UbuntuServerEditViewController" bundle:nil];
		if ([ubuntuServerEditViewController respondsToSelector:@selector(setModalPresentationStyle:)])
			ubuntuServerEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
		[self presentModalViewController:ubuntuServerEditViewController animated:YES];
		[ubuntuServerEditViewController release];
	}
	else // Default to Subsonic
	{
		SubsonicServerEditViewController *subsonicServerEditViewController = [[SubsonicServerEditViewController alloc] initWithNibName:@"SubsonicServerEditViewController" bundle:nil];
		if ([subsonicServerEditViewController respondsToSelector:@selector(setModalPresentationStyle:)])
			subsonicServerEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
		[self presentModalViewController:subsonicServerEditViewController animated:YES];
		[subsonicServerEditViewController release];
	}
}

- (void)switchServer:(NSNotification*)notification 
{	
	if (notification.userInfo)
	{
		self.theNewRedirectionUrl = [notification.userInfo objectForKey:@"theNewRedirectUrl"];
	}
	
	// Save the plist values
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[defaults setObject:viewObjects.serverToEdit.url forKey:@"url"];
	[defaults setObject:viewObjects.serverToEdit.username forKey:@"username"];
	[defaults setObject:viewObjects.serverToEdit.password forKey:@"password"];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settings.serverList] forKey:@"servers"];
	[defaults synchronize];
	
	// Update the variables
	settings.urlString = [NSString stringWithString:viewObjects.serverToEdit.url];
	settings.username = [NSString stringWithString:viewObjects.serverToEdit.username];
	settings.password = [NSString stringWithString:viewObjects.serverToEdit.password];
    settings.redirectUrlString = self.theNewRedirectionUrl;
		
	[self retain];
	if(self == [[self.navigationController viewControllers] objectAtIndex:0])
	{
		[self.navigationController.view removeFromSuperview];
	}
	else
	{
		[self.navigationController popToRootViewControllerAnimated:YES];
		
		if ([appDelegate.wifiReach currentReachabilityStatus] == NotReachable)
			return;
		
		// Cancel any tab loads
		if (viewObjects.isAlbumsLoading || viewObjects.isSongsLoading)
		{
			if (viewObjects.isAlbumsLoading)
			{
				DLog(@"detected albums tab loading");
			}
			else if (viewObjects.isSongsLoading)
			{
				DLog(@"detected songs tab loading");
			}
			
			viewObjects.cancelLoading = YES;
		}
		
		while (viewObjects.cancelLoading == YES)
		{
			DLog(@"waiting for the load to cancel before continuing");
		}
		
		// Stop any playing song and remove old tab bar controller from window
		[[NSUserDefaults standardUserDefaults] setObject:@"NO" forKey:@"recover"];
		[[NSUserDefaults standardUserDefaults] synchronize];
		[[BassWrapperSingleton sharedInstance] stop];
		settings.isJukeboxEnabled = NO;
		musicControls.showNowPlayingIcon = NO;
		
		if (!IS_IPAD())
			[appDelegate.mainTabBarController.view removeFromSuperview];
		
		// Reset the databases
		[databaseControls closeAllDatabases];
		
		[databaseControls initDatabases];
				
		if (viewObjects.isOfflineMode)
		{
			viewObjects.isOfflineMode = NO;
			
			if (!IS_IPAD())
			{
				[appDelegate.offlineTabBarController.view removeFromSuperview];
				[viewObjects orderMainTabBarController];
			}
		}
		
		// Reset the tabs
		//[viewObjects loadArtistList];
		[[NSNotificationCenter defaultCenter] postNotificationName:@"reloadArtistList" object:nil];
		if (IS_IPAD())
			[appDelegate.artistsNavigationController popToRootViewControllerAnimated:NO];
		else
			[appDelegate.rootViewController.navigationController popToRootViewControllerAnimated:NO];
		//[appDelegate.allAlbumsNavigationController.topViewController viewDidLoad];
		//[appDelegate.allSongsNavigationController.topViewController viewDidLoad];
		[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_SongPlaybackStarted object:nil];
		
		// Add the tab bar controller back to the window
		if (!IS_IPAD())
			[appDelegate.window addSubview:[appDelegate.mainTabBarController view]];
		
		appDelegate.window.backgroundColor = viewObjects.windowColor;
		
		[[NSNotificationCenter defaultCenter] postNotificationName:ISMSNotification_ServerSwitched object:nil];
	}
}

#pragma mark Table view methods

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	if (segmentedControl.selectedSegmentIndex == 0)
		return [settings.serverList count];
	else
		return 0;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *CellIdentifier = @"Cell";
	
	UITableViewCell *cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
	Server *aServer = [settings.serverList objectAtIndex:indexPath.row];
	
	// Set up the cell...
	UILabel *serverNameLabel = [[UILabel alloc] init];
	serverNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	serverNameLabel.backgroundColor = [UIColor clearColor];
	serverNameLabel.textAlignment = UITextAlignmentLeft; // default
	serverNameLabel.font = [UIFont boldSystemFontOfSize:20];
	[serverNameLabel setText:aServer.url];
	[cell.contentView addSubview:serverNameLabel];
	[serverNameLabel release];
	
	UILabel *detailsLabel = [[UILabel alloc] init];
	detailsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textAlignment = UITextAlignmentLeft; // default
	detailsLabel.font = [UIFont systemFontOfSize:15];
	[detailsLabel setText:[NSString stringWithFormat:@"username: %@", aServer.username]];
	[cell.contentView addSubview:detailsLabel];
	[detailsLabel release];
	
	UIImage *typeImage = nil;
	if ([aServer.type isEqualToString:SUBSONIC])
		typeImage = [UIImage imageNamed:@"server-subsonic.png"];
	else if ([aServer.type isEqualToString:UBUNTU_ONE])
		typeImage = [UIImage imageNamed:@"server-ubuntu.png"];

	UIImageView *serverType = [[UIImageView alloc] initWithImage:typeImage];
	serverType.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[cell.contentView addSubview:serverType];
	[serverType release];
	
	if([settings.urlString isEqualToString:aServer.url] && 
	   [settings.username isEqualToString:aServer.username] &&
	   [settings.password isEqualToString:aServer.password])
	{
		UIImageView *currentServerMarker = [[UIImageView alloc] init];
		currentServerMarker.image = [UIImage imageNamed:@"current-server.png"];
		[cell.contentView addSubview:currentServerMarker];
		[currentServerMarker release];
		
		currentServerMarker.frame = CGRectMake(3, 12, 26, 26);
		serverNameLabel.frame = CGRectMake(35, 0, 236, 25);
		detailsLabel.frame = CGRectMake(35, 27, 236, 18);
	}
	else 
	{
		serverNameLabel.frame = CGRectMake(5, 0, 266, 25);
		detailsLabel.frame = CGRectMake(5, 27, 266, 18);
	}
	serverType.frame = CGRectMake(271, 3, 44, 44);
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
		cell.backgroundView.backgroundColor = [viewObjects lightNormal];
	else
		cell.backgroundView.backgroundColor = [viewObjects darkNormal];
	
	return cell;
}


- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	viewObjects.serverToEdit = [settings.serverList objectAtIndex:indexPath.row];

	if (isEditing)
	{
		[self showServerEditScreen];
	}
	else
	{
		self.theNewRedirectionUrl = nil;
		[viewObjects showLoadingScreenOnMainWindow];
		SUSServerURLChecker *checker = [[SUSServerURLChecker alloc] initWithDelegate:self];
		[checker checkURL:[NSURL URLWithString:[NSString stringWithFormat:@"%@/rest/ping.view", viewObjects.serverToEdit.url]]];
	}
}

// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}


- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath 
{
	return YES;
}


- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath 
{
	NSArray *server = [[settings.serverList objectAtIndex:fromIndexPath.row] retain];
	[settings.serverList removeObjectAtIndex:fromIndexPath.row];
	[settings.serverList insertObject:server atIndex:toIndexPath.row];
	[server release];
	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject:settings.serverList] forKey:@"servers"];
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	[self.tableView reloadData];
}


// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) 
	{
		// Alert user to select new default server if they deleting the default
		if ([settings.urlString isEqualToString:[(Server *)[settings.serverList objectAtIndex:indexPath.row] url]])
		{
			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Make sure to select a new server" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			alert.tag = 4;
			[alert show];
			[alert release];
		}
		
        // Delete the row from the data source
        [settings.serverList removeObjectAtIndex:indexPath.row];
		[tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationNone];
		[self.tableView reloadData];
		
		// Save the plist values
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		/*if ([viewObjects.serverList count] == 0)
		{
			[defaults setObject:DEFAULT_URL forKey:@"url"];
			[defaults setObject:DEFAULT_USER_NAME forKey:@"username"];
			[defaults setObject:DEFAULT_PASSWORD forKey:@"password"];
			
			appDelegate.defaultUrl = [NSString stringWithString:viewObjects.serverToEdit.url];
			appDelegate.defaultUserName = [NSString stringWithString:viewObjects.serverToEdit.username];
			appDelegate.defaultPassword = [NSString stringWithString:viewObjects.serverToEdit.password];
		}*/
		[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:settings.serverList] forKey:@"servers"];
		[defaults synchronize];
    }   
}


- (void)dealloc 
{
	[theNewRedirectionUrl release]; theNewRedirectionUrl = nil;
    [super dealloc];
}

- (void)SUSServerURLCheckFailed:(SUSServerURLChecker *)checker withError:(NSError *)error
{
	DLog(@"server check failed");
    if(!viewObjects.isOfflineMode)
	{
		viewObjects.isOfflineMode = YES;
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %i:\n%@", [error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		alert.tag = 3;
		[alert show];
		[alert release];		
	}
    
    [checker release]; checker = nil;
	    
    DLog(@"server verification failed, hiding loading screen");
    [viewObjects hideLoadingScreen];
}

- (void)SUSServerURLCheckPassed:(SUSServerURLChecker *)checker
{
	settings.isNewSearchAPI = checker.isNewSearchAPI;
    
    [checker release]; checker = nil;
	
	[self switchServer:nil];
    
    DLog(@"server verification passed, hiding loading screen");
    [viewObjects hideLoadingScreen];
}

- (void)SUSServerURLCheckRedirected:(SUSServerURLChecker *)checker redirectUrl:(NSURL *)url
{
    self.theNewRedirectionUrl = [NSString stringWithFormat:@"%@://%@:%@", url.scheme, url.host, url.port];
}

@end

