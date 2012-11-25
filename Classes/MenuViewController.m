//
//  MenuViewController.m
//  StackScrollView
//
//  Created by Reefaq on 2/24/11.
//  Copyright 2011 raw engineering . All rights reserved.
//

#import "MenuViewController.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"
#import "MenuTableViewCell.h"
#import "NewHomeViewController.h"
#import "FoldersViewController.h"
#import "AllAlbumsViewController.h"
#import "AllSongsViewController.h"
#import "PlaylistsViewController.h"
#import "PlayingViewController.h"
#import "BookmarksViewController.h"
#import "GenresViewController.h"
#import "CacheViewController.h"
#import "ChatViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "ServerListViewController.h"

#define kCellText @"CellText"
#define kCellImage @"CellImage"

@implementation MenuViewController
@synthesize tableView, cellContents, isFirstLoad, lastSelectedRow, playerHolder, playerController, playerNavController;

#pragma mark -
#pragma mark View lifecycle

- (void)toggleOfflineMode
{
	self.isFirstLoad = YES;
	[self loadCellContents];
	[self viewDidAppear:YES];
}

- (id)initWithFrame:(CGRect)frame
{
    if (self = [super init])
	{
		[self.view setFrame:frame];
		
		// Create the background color
		UIView *background = [[UIView alloc] initWithFrame:self.view.frame];
		background.backgroundColor = [UIColor scrollViewTexturedBackgroundColor];
		UIView *shade = [[UIView alloc] initWithFrame:self.view.frame];
		shade.backgroundColor = [[UIColor blackColor] colorWithAlphaComponent:0.7];
		[background addSubview:shade];
		[self.view addSubview:background];
        
        playerHolder = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 440)];
        playerHolder.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
        playerHolder.bottom = self.view.bottom;
        [self.view addSubview:playerHolder];
		
		playerController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
		playerNavController = [[UINavigationController alloc] initWithRootViewController:playerController];
		playerNavController.view.frame = CGRectMake(0, 0, 320, 440);
        playerNavController.navigationBar.tintColor = [UIColor blackColor];
		//playerNavController.view.bottom = self.view.bottom;
		//playerNavController.view.autoresizingMask = UIViewAutoresizingFlexibleTopMargin;
		//[self.view addSubview:playerNavController.view];
        [self.playerHolder addSubview:playerNavController.view];
		
		// Create the menu
		[self loadCellContents];
		tableView = [[UITableView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 565.) style:UITableViewStylePlain];
	//DLog(@"tableView.frame: %@", NSStringFromCGRect(tableView.frame));
		tableView.delegate = self;
		tableView.dataSource = self;
		tableView.autoresizingMask = UIViewAutoresizingFlexibleHeight;
		tableView.backgroundColor = [UIColor clearColor];
		tableView.separatorStyle = UITableViewCellSeparatorStyleNone;
		
		// Create the header and footer
		UIView *headerView = [self createHeaderView:NO];
		UIView *footerView = [self createFooterView];
		self.tableView.tableHeaderView = headerView;
		self.tableView.tableFooterView = footerView;
		
		[self.view addRightShadowWithWidth:12. alpha:0.5];
		
		isFirstLoad = YES;
		lastSelectedRow = NSIntegerMax;
	
		[self.view addSubview:tableView];
		
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(showSettings) name:@"show settings" object:nil];
	}
    return self;
}

- (UIView *)createHeaderView:(BOOL)withImage
{
	CGFloat height = withImage ? 70. : 1.;
	UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, height)];
	
	if (withImage)
	{
		UIImageView *imageView = [[UIImageView alloc] initWithFrame:CGRectMake(11, 11, 48, 48)];
		imageView.contentMode = UIViewContentModeScaleAspectFit;
		imageView.layer.cornerRadius = 3.f;
		imageView.layer.masksToBounds = NO;
		imageView.layer.shadowColor = [[UIColor blackColor] CGColor];
		imageView.layer.shadowOffset = CGSizeMake(0, 3);
		imageView.layer.shadowOpacity = 0.5f;
		imageView.layer.shadowRadius = 3.0f;
		imageView.layer.shouldRasterize = YES;
		imageView.image = [UIImage imageNamed:@"default-album-art.png"];
		[headerView addSubview:imageView];
		
		UILabel *textLabel = [[UILabel alloc] initWithFrame:CGRectMake(70, 11, self.view.width - 70, 48)];
		textLabel.font = [UIFont boldSystemFontOfSize:[UIFont labelFontSize]];
		textLabel.textColor = [UIColor colorWithRed:(188.f/255.f) green:(188.f/255.f) blue:(188.f/255.f) alpha:1.f];
		textLabel.shadowOffset = CGSizeMake(0, 2);
		textLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.text = @"iSub Music Streamer";
		[headerView addSubview:textLabel];
	}
	
	UIView* bottomLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 1)];//69, self.view.width, 1)];
	bottomLine.backgroundColor = [UIColor colorWithWhite:0. alpha:0.25];
	[headerView addSubview:bottomLine];
	
	//self.tableView.tableHeaderView = headerView;
	//[headerView release];
	return headerView;
}

- (UIView *)createFooterView
{
	UIView *footerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 200, 1)];//80)];
	
	UIView* topLine = [[UIView alloc] initWithFrame:CGRectMake(0, 0, self.view.width, 1)];
	topLine.backgroundColor = [UIColor colorWithWhite:0.5 alpha:0.25];
	[footerView addSubview:topLine];
	
	UIImageView *watermark = [[UIImageView alloc] initWithFrame:CGRectMake(0, 20, self.view.width, 175)];
	watermark.contentMode = UIViewContentModeCenter;
	watermark.image = [UIImage imageNamed:@"intro-sunkenlogo.png"];
	[footerView addSubview:watermark];
	
	//self.tableView.tableFooterView = footerView;
	//[footerView release];
	return footerView;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	if (self.isFirstLoad)
	{
		self.isFirstLoad = NO;
		[self showHome];
	}
}

- (BOOL)shouldAutorotate
{
    return [self shouldAutorotateToInterfaceOrientation:[UIDevice currentDevice].orientation];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation 
{
	if (settingsS.isRotationLockEnabled && interfaceOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    // Override to allow orientations other than the default portrait orientation.
    return YES;
}

- (void)loadCellContents
{
	self.tableView.scrollEnabled = NO;
	
	self.cellContents = [NSMutableArray arrayWithCapacity:10];
	
    if (appDelegateS.referringAppUrl)
    {
        [self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"back-tabbaricon.png"], kCellImage, @"Back", kCellText, nil]];
    }
    
	if (settingsS.isOfflineMode)
	{
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"settings-tabbaricon.png"], kCellImage, @"Settings", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"folders-tabbaricon.png"], kCellImage, @"Folders", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"genres-tabbaricon.png"], kCellImage, @"Genres", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"playlists-tabbaricon.png"], kCellImage, @"Playlists", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"bookmarks-tabbaricon.png"], kCellImage, @"Bookmarks", kCellText, nil]];
	}
	else
	{
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"settings-tabbaricon.png"], kCellImage, @"Settings", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"home-tabbaricon.png"], kCellImage, @"Home", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"folders-tabbaricon.png"], kCellImage, @"Folders", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"playlists-tabbaricon.png"], kCellImage, @"Playlists", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"playing-tabbaricon.png"], kCellImage, @"Now Playing", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"bookmarks-tabbaricon.png"], kCellImage, @"Bookmarks", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"cache-tabbaricon.png"], kCellImage, @"Cache", kCellText, nil]];
		[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"chat-tabbaricon.png"], kCellImage, @"Chat", kCellText, nil]];
		
		if (settingsS.isSongsTabEnabled)
		{
			self.tableView.scrollEnabled = YES;
			[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"genres-tabbaricon.png"], kCellImage, @"Genres", kCellText, nil]];
			[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"albums-tabbaricon.png"], kCellImage, @"Albums", kCellText, nil]];
			[self.cellContents addObject:[NSDictionary dictionaryWithObjectsAndKeys:[UIImage imageNamed:@"songs-tabbaricon.png"], kCellImage, @"Songs", kCellText, nil]];
		}
	}
	
	[self.tableView reloadData];    
}

- (void)showSettings
{
	[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
	[self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
}

- (void)showHome
{
	//[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
	//[self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:0 inSection:0]];
	
	[self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0] animated:NO scrollPosition:UITableViewScrollPositionMiddle];
	[self tableView:self.tableView didSelectRowAtIndexPath:[NSIndexPath indexPathForRow:1 inSection:0]];
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return self.cellContents.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
    static NSString *cellIdentifier = @"MenuTableViewCell";
	MenuTableViewCell *cell = (MenuTableViewCell*)[self.tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (cell == nil) 
	{
        cell = [[MenuTableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
	
	cell.textLabel.text = [[self.cellContents objectAtIndex:indexPath.row] objectForKey:kCellText];
	cell.imageView.image = [[self.cellContents objectAtIndex:indexPath.row] objectForKey:kCellImage];
	cell.glowView.hidden = YES;
	cell.imageView.alpha = 0.6;

    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
    
    // Handle the special case of the back button / ref url
    if (appDelegateS.referringAppUrl)
    {
        if (indexPath.row == 0)
        {
            // Fix the cell highlighting
            [self.tableView deselectRowAtIndexPath:indexPath animated:NO];
            [self.tableView selectRowAtIndexPath:[NSIndexPath indexPathForRow:self.lastSelectedRow inSection:0] animated:NO scrollPosition:UITableViewScrollPositionNone];
            
            // Go back to the other app
            [[UIApplication sharedApplication] openURL:appDelegateS.referringAppUrl];
            return;
        }
    }
	
	// Set the tabel cell glow
	//
	for (MenuTableViewCell *cell in self.tableView.visibleCells)
	{
		cell.glowView.hidden = YES;
		cell.imageView.alpha = 0.6;
	}
	[[(MenuTableViewCell *)[self.tableView cellForRowAtIndexPath:indexPath] glowView] setHidden:NO];
	[self.tableView cellForRowAtIndexPath:indexPath].imageView.alpha = 1.0;
		
	[self performSelector:@selector(showControllerForIndexPath:) withObject:indexPath afterDelay:0.05];
}

- (void)showControllerForIndexPath:(NSIndexPath *)indexPath
{
    // If we have the back button displayed, subtract 1 from the row to get the correct action
    NSUInteger row = appDelegateS.referringAppUrl ? indexPath.row - 1 : indexPath.row;
    
	// Present the view controller
	//
	UIViewController *controller;
	
	if (settingsS.isOfflineMode)
	{
		switch (row) 
		{
			case 0:
			{
				ServerListViewController *settings = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
				UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settings];
				navController.navigationBar.tintColor = [UIColor blackColor];
				controller = (UIViewController *)navController;
				break;
			}
			case 1: controller = [[CacheViewController alloc] initWithNibName:@"CacheViewController" bundle:nil]; break;
			case 2: controller = [[GenresViewController alloc] initWithNibName:@"GenresViewController" bundle:nil]; break;
			case 3: controller = [[PlaylistsViewController alloc] initWithNibName:@"PlaylistsViewController" bundle:nil]; break;
			case 4: controller = [[BookmarksViewController alloc] initWithNibName:@"BookmarksViewController" bundle:nil]; break;
			
			default: controller = nil;
		}
	}
	else
	{
		switch (row) 
		{
			case 0:
			{
				ServerListViewController *settings = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
				UINavigationController *navController = [[UINavigationController alloc] initWithRootViewController:settings];
				navController.navigationBar.tintColor = [UIColor blackColor];
				controller = (UIViewController *)navController;
				break;
			}
			case 1: controller = [[NewHomeViewController alloc] initWithNibName:@"NewHomeViewController-iPad" bundle:nil]; break;
			case 2: controller = [[FoldersViewController alloc] initWithNibName:@"FoldersViewController" bundle:nil]; break;
			case 3: controller = [[PlaylistsViewController alloc] initWithNibName:@"PlaylistsViewController" bundle:nil]; break;
			case 4: controller = [[PlayingViewController alloc] initWithNibName:@"PlayingViewController" bundle:nil]; break;
			case 5: controller = [[BookmarksViewController alloc] initWithNibName:@"BookmarksViewController" bundle:nil]; break;
			case 6: controller = [[CacheViewController alloc] initWithNibName:@"CacheViewController" bundle:nil]; break;
			case 7: controller = [[ChatViewController alloc] initWithNibName:@"ChatViewController" bundle:nil]; break;
			
			case 8: controller = [[GenresViewController alloc] initWithNibName:@"GenresViewController" bundle:nil]; break;
			case 9: controller = [[AllAlbumsViewController alloc] initWithNibName:@"AllAlbumsViewController" bundle:nil]; break;
			case 10: controller = [[AllSongsViewController alloc] initWithNibName:@"AllSongsViewController" bundle:nil]; break;
			default: controller = nil;
		}
	}
	
	controller.view.width = ISMSiPadViewWidth;
	controller.view.layer.cornerRadius = ISMSiPadCornerRadius;
	controller.view.layer.masksToBounds = YES;
	[[iSubAppDelegate sharedInstance].ipadRootViewController.stackScrollViewController addViewInSlider:controller invokeByController:self isStackStartView:YES];
	
	self.lastSelectedRow = indexPath.row;
}

#pragma mark - Memory management

- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
}


@end

