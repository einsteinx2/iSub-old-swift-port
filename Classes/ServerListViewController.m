//
//  ServerListViewController.m
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ServerListViewController.h"
#import "Imports.h"
#import "SubsonicServerEditViewController.h"
#import "SettingsTabViewController.h"
#import "HelpTabViewController.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "iSub-Swift.h"

@interface ServerListViewController ()
@property (nonatomic, strong) NSArray<ISMSServer*> *servers;
@property (nonatomic) BOOL isEditing;
@property (nonatomic, strong) UIView *headerView;
@property (nonatomic, strong) UISegmentedControl *segmentedControl;
@property (nonatomic, copy) NSString *redirectUrl;
@property (nonatomic, strong) SettingsTabViewController *settingsTabViewController;
@property (nonatomic, strong) HelpTabViewController *helpTabViewController;
- (void)addAction:(id)sender;
- (void)segmentAction:(id)sender;
@end

@implementation ServerListViewController

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
    
	self.redirectUrl = nil;
	
	self.tableView.allowsSelectionDuringEditing = YES;
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTable) name:@"reloadServerList" object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showSaveButton) name:@"showSaveButton" object:nil];
	
	self.title = @"Servers";
	
	if ([[ISMSServer allServers] count] == 0)
		[self addAction:nil];
	
	// Setup segmented control in the header view
	self.headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 40)];
	self.headerView.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
	
	self.segmentedControl = [[UISegmentedControl alloc] initWithItems:@[@"Servers", @"Settings", @"Help"]];
	self.segmentedControl.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	[self.segmentedControl addTarget:self action:@selector(segmentAction:) forControlEvents:UIControlEventValueChanged];
	self.segmentedControl.frame = CGRectMake(5, 2, 310, 36);
    self.segmentedControl.tintColor = ISMSHeaderColor;
	self.segmentedControl.selectedSegmentIndex = 0;
	[self.headerView addSubview:self.segmentedControl];
	
	self.tableView.tableHeaderView = self.headerView;
	
	if (!IS_IPAD())
	{
		if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];
	}
}

// Add close button
- (UIBarButtonItem *)setupLeftBarButton
{
    return [[UIBarButtonItem alloc] initWithTitle:@"Close"
                                            style:UIBarButtonItemStylePlain
                                           target:self
                                           action:@selector(close:)];
}

- (void)close:(id)sender
{
    [self dismissViewControllerAnimated:YES completion:nil];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    if(self != [[self.navigationController viewControllers] objectAtIndexSafe:0])
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(saveAction:)];
    self.navigationItem.rightBarButtonItem = self.editButtonItem;
}

- (void)reloadTable
{
    self.servers = [ISMSServer allServers];
	[self.tableView reloadData];
}

- (void)showSaveButton
{
	if(!self.isEditing)
	{
		if(self == [[self.navigationController viewControllers] firstObjectSafe])
			self.navigationItem.leftBarButtonItem = nil;
		else
			self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back" style:UIBarButtonItemStylePlain target:self action:@selector(saveAction:)];
		
	}
}

- (void)segmentAction:(id)sender
{
	self.settingsTabViewController.parentController = nil;
	self.settingsTabViewController = nil;
	self.helpTabViewController = nil;
	
	if (self.segmentedControl.selectedSegmentIndex == 0)
	{
		self.title = @"Servers";
		
		self.tableView.tableFooterView = nil;
		
		self.tableView.scrollEnabled = YES;
		self.navigationItem.rightBarButtonItem = self.editButtonItem;
		
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
		
		[self.tableView reloadData];
	}
	else if (self.segmentedControl.selectedSegmentIndex == 1)
	{
		self.title = @"Settings";
		
		self.tableView.scrollEnabled = YES;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		self.settingsTabViewController = [[SettingsTabViewController alloc] initWithNibName:@"SettingsTabViewController" bundle:nil];
		self.settingsTabViewController.parentController = self;
		self.tableView.tableFooterView = self.settingsTabViewController.view;
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
		[self.tableView reloadData];
	}
	else if (self.segmentedControl.selectedSegmentIndex == 2)
	{
		self.title = @"Help";
		
		self.tableView.scrollEnabled = NO;
		[self setEditing:NO animated:NO];
		self.navigationItem.rightBarButtonItem = nil;
		self.helpTabViewController = [[HelpTabViewController alloc] initWithNibName:@"HelpTabViewController" bundle:nil];
		self.helpTabViewController.view.frame = self.view.bounds;
        self.helpTabViewController.view.height -= 40.;
		self.tableView.tableFooterView = self.helpTabViewController.view;
		if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
		[self.tableView reloadData];
	}
}

- (void)setEditing:(BOOL)editing animated:(BOOL)animate
{
    [super setEditing:editing animated:animate];
    if(editing)
    {
		self.isEditing = YES;
		self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemAdd target:self action:@selector(addAction:)];
    }
    else
    {
		self.isEditing = NO;
		[self showSaveButton];
    }
}

- (void)addAction:(id)sender
{
    SubsonicServerEditViewController *subsonicServerEditViewController = [[SubsonicServerEditViewController alloc] initWithServer:nil];
    subsonicServerEditViewController.view.frame = self.view.bounds;
    subsonicServerEditViewController.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
    
    [Flurry logEvent:@"ServerType" withParameters:[NSDictionary dictionaryWithObject:@"Subsonic" forKey:@"type"]];
    
    if (IS_IPAD())
        [appDelegateS.ipadRootViewController presentViewController:subsonicServerEditViewController animated:YES completion:nil];
    else
        [self presentViewController:subsonicServerEditViewController animated:YES completion:nil];
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

- (void)showServerEditScreen:(ISMSServer *)server
{
    if (server.type == ServerTypeSubsonic)
    {
        SubsonicServerEditViewController *subsonicServerEditViewController = [[SubsonicServerEditViewController alloc] initWithServer:server];
        if ([subsonicServerEditViewController respondsToSelector:@selector(setModalPresentationStyle:)])
            subsonicServerEditViewController.modalPresentationStyle = UIModalPresentationFormSheet;
        [self presentViewController:subsonicServerEditViewController animated:YES completion:nil];
    }
}

#pragma mark - Table view methods -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView {
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (self.segmentedControl.selectedSegmentIndex == 0)
        return self.servers.count;
	else
		return 0;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"ServerListCell";
    UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	
    ISMSServer *server = self.servers[indexPath.row];
	
	// Set up the cell...
	UILabel *serverNameLabel = [[UILabel alloc] init];
	serverNameLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	serverNameLabel.backgroundColor = [UIColor clearColor];
	serverNameLabel.textAlignment = NSTextAlignmentLeft; // default
	serverNameLabel.font = ISMSBoldFont(20);
	[serverNameLabel setText:server.url];
	[cell.contentView addSubview:serverNameLabel];
	
	UILabel *detailsLabel = [[UILabel alloc] init];
	detailsLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	detailsLabel.backgroundColor = [UIColor clearColor];
	detailsLabel.textAlignment = NSTextAlignmentLeft; // default
	detailsLabel.font = ISMSRegularFont(15);
	[detailsLabel setText:[NSString stringWithFormat:@"username: %@", server.username]];
	[cell.contentView addSubview:detailsLabel];
	
	UIImage *typeImage = nil;
	if (server.type == ServerTypeSubsonic)
		typeImage = [UIImage imageNamed:@"server-subsonic"];

	UIImageView *serverType = [[UIImageView alloc] initWithImage:typeImage];
	serverType.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[cell.contentView addSubview:serverType];
	
	if([settingsS.currentServer isEqual:server])
	{
		UIImageView *currentServerMarker = [[UIImageView alloc] init];
		currentServerMarker.image = [UIImage imageNamed:@"current-server"];
		[cell.contentView addSubview:currentServerMarker];
		
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
	
    cell.backgroundView = [[UIView alloc] init];
	
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	ISMSServer *server = self.servers[indexPath.row];

    // TODO: Figure out better way to get into edit mode, it's not intuitive
	if (self.isEditing)
	{
        [self showServerEditScreen:server];
	}
	else
	{
		self.redirectUrl = nil;
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Checking Server"];
        
        ISMSStatusLoader *statusLoader = [[ISMSStatusLoader alloc] initWithServer:server];
        statusLoader.delegate = self;
        [statusLoader startLoad];
	}
}

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
    // TODO: Figure out how to implement this using the new data model. Or turn off move support.
    
//	NSArray *server = [ settingsS.serverList objectAtIndexSafe:fromIndexPath.row];
//	[settingsS.serverList removeObjectAtIndex:fromIndexPath.row];
//	[settingsS.serverList insertObject:server atIndex:toIndexPath.row];
//	[[NSUserDefaults standardUserDefaults] setObject:[NSKeyedArchiver archivedDataWithRootObject: settingsS.serverList] forKey:@"servers"];
//	[[NSUserDefaults standardUserDefaults] synchronize];
//	
//	[self.tableView reloadData];
}

- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath
{
    if (editingStyle == UITableViewCellEditingStyleDelete) 
	{
        // TODO: Automatically switch to the next server. Or if it's the last server, connect to the test server
//		// Alert user to select new default server if they deleting the default
//		if ([ settingsS.urlString isEqualToString:[(ISMSServer *)[ settingsS.serverList objectAtIndexSafe:indexPath.row] url]])
//		{
//			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Make sure to select a new server" delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
//			alert.tag = 4;
//			[alert show];
//		}
		
        // Delete the row from the data source
        ISMSServer *server = self.servers[indexPath.row];
        [server deleteModel];
		
		@try
		{
			[tableView deleteRowsAtIndexPaths:@[indexPath] withRowAnimation:UITableViewRowAnimationAutomatic];
		}
		@catch (NSException *exception) 
		{
            //DLog(@"Exception: %@ - %@", exception.name, exception.reason);
		}
    }   
}

- (void)loadingRedirected:(ISMSLoader *)theLoader redirectUrl:(NSURL *)url
{
    NSMutableString *redirectUrlString = [NSMutableString stringWithFormat:@"%@://%@", url.scheme, url.host];
	if (url.port)
		[redirectUrlString appendFormat:@":%@", url.port];
	
	if ([url.pathComponents count] > 3)
	{
		for (NSString *component in url.pathComponents)
		{
			if ([component isEqualToString:@"api"] || [component isEqualToString:@"rest"])
				break;
			
			if (![component isEqualToString:@"/"])
			{
				[redirectUrlString appendFormat:@"/%@", component];
			}
		}
	}
	
    DLog(@"redirectUrlString: %@", redirectUrlString);
	
	self.redirectUrl = [NSString stringWithString:redirectUrlString];
}

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    UIAlertView *alert = nil;
	if (error.code == ISMSErrorCode_IncorrectCredentials)
	{
		alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either your username or password is incorrect\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %li:\n%@", (long)[error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	}
	else
	{
		alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %li:\n%@", (long)[error code], [error localizedDescription]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
	}
	alert.tag = 3;
	[alert show];
        
    DLog(@"server verification failed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
}

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    ISMSStatusLoader *statusLoader = (ISMSStatusLoader *)statusLoader;
    
    settingsS.currentServer = statusLoader.server;
    settingsS.redirectUrlString = self.redirectUrl;
	
	[appDelegateS switchServer:statusLoader.server redirectUrl:self.redirectUrl];
    
    DLog(@"server verification passed, hiding loading screen");
    [viewObjectsS hideLoadingScreen];
}

@end

