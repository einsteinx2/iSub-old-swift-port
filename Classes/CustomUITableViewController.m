//
//  CustomUITableViewController.m
//  iSub
//
//  Created by Benjamin Baron on 10/9/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"

@implementation CustomUITableViewController

#pragma mark - Rotation -

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark - Lifecycle -

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_jukeboxToggled:) name:ISMSNotification_JukeboxEnabled object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_jukeboxToggled:) name:ISMSNotification_JukeboxDisabled object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupLeftBarButton) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [self setupRefreshControl];
    
    if (IS_IPAD())
    {
        self.view.backgroundColor = ISMSiPadBackgroundColor;
    }
    
    UITableView *tableView = self.tableView;
    tableView.tableHeaderView = [self setupHeaderView];
    // Keep the table rows from showing past the bottom
    if (!tableView.tableFooterView) tableView.tableFooterView = [[UIView alloc] init];
    [self customizeTableView:tableView];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
    
    [self _updateBackgroundColor];
    
    UINavigationItem *navigationItem = self.navigationController.navigationItem;
    navigationItem.leftBarButtonItem = [self setupLeftBarButton];
    navigationItem.rightBarButtonItem = [self setupRightBarButton];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_JukeboxEnabled object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_JukeboxDisabled object:nil];
    [[NSNotificationCenter defaultCenter] removeObserver:self name:UIApplicationDidBecomeActiveNotification object:nil];
}

#pragma mark - Private -

- (void)_updateBackgroundColor
{
    self.view.backgroundColor = settingsS.isJukeboxEnabled ? viewObjectsS.jukeboxColor : viewObjectsS.windowColor;
}

#pragma mark Notifications

- (void)_jukeboxToggled:(NSNotification *)notification
{
    [self _updateBackgroundColor];
}

#pragma mark - UI -

#pragma mark Initial Setup

- (UIView *)setupHeaderView
{
    // Override to provide a custom header
    return nil;
}

- (void)customizeTableView:(UITableView *)tableView
{
    
}

- (UIBarButtonItem *)setupLeftBarButton
{
    BOOL isRootViewController = self.navigationController.viewControllers[0] == self;
    BOOL isInsideMoreTab = appDelegateS.mainTabBarController.selectedIndex == 4;
    
    UIBarButtonItem *leftBarButtonItem = nil;
    
    if (isRootViewController)
    {
        if (settingsS.isOfflineMode)
        {
            leftBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"]
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:self
                                                                action:@selector(a_settings:)];
        }
        else if (appDelegateS.referringAppUrl && !isInsideMoreTab)
        {
            // Add a back button to return to the reffering app if there is one and we're the root controller
            leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                 style:UIBarButtonItemStyleBordered
                                                                target:appDelegateS
                                                                action:@selector(backToReferringApp)];
        }
    }
    
    return leftBarButtonItem;
}

- (UIBarButtonItem *)setupRightBarButton
{
    UIBarButtonItem *rightBarButtonItem = nil;
    
    if(musicS.showPlayerIcon)
    {
        rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"]
                                                              style:UIBarButtonItemStyleBordered
                                                             target:self
                                                             action:@selector(a_nowPlaying:)];
    }
    
    return rightBarButtonItem;
}

#pragma mark Pull to Refresh

- (BOOL)shouldSetupRefreshControl
{
    return NO;
}

- (void)setupRefreshControl
{
    if ([self shouldSetupRefreshControl] && !self.refreshControl)
    {
        UIRefreshControl *refreshControl = [[UIRefreshControl alloc] init];
        UIColor *tintColor = [UIColor whiteColor];
        refreshControl.attributedTitle = [[NSAttributedString alloc] initWithString:@"Pull down to reload..."
                                                                         attributes:@{NSForegroundColorAttributeName:tintColor}];
        refreshControl.tintColor = tintColor;
        [refreshControl addTarget:self
                           action:@selector(didPullToRefresh)
                 forControlEvents:UIControlEventValueChanged];
        self.refreshControl = refreshControl;
    }
}

- (void)didPullToRefresh
{
    NSAssert(NO, @"didPullToRefresh must be overridden");
}

#pragma mark - Actions -

- (void)a_settings:(id)sender
{
    ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
    serverListViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:serverListViewController animated:YES];
}

- (void)a_nowPlaying:(id)sender
{
    iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
    streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

@end
