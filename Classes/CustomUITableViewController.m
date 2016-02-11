//
//  CustomUITableViewController.m
//  iSub
//
//  Created by Benjamin Baron on 10/9/13.
//  Copyright (c) 2013 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"
#import "Imports.h"
#import "ServerListViewController.h"
#import "iSub-Swift.h"
#import <JASidePanels/JASidePanelController.h>
#import <JASidePanels/UIViewController+JASidePanel.h>

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
    
    self.navigationController.navigationBar.barStyle = UIBarStyleBlack;
    self.edgesForExtendedLayout = UIRectEdgeNone;
    
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_jukeboxToggled:) name:ISMSNotification_JukeboxEnabled object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_jukeboxToggled:) name:ISMSNotification_JukeboxDisabled object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(setupLeftBarButton) name:UIApplicationDidBecomeActiveNotification object:nil];
    
    [self setupRefreshControl];
    
    if (IS_IPAD())
    {
        self.view.backgroundColor = ISMSiPadBackgroundColor;
    }
    
    if (!self.tableView)
    {
        self.tableView = [[UITableView alloc] init];
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
    
    UINavigationItem *navigationItem = self.navigationItem;
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
    return [[UIBarButtonItem alloc] initWithTitle:@"Menu"
                                            style:UIBarButtonItemStylePlain
                                           target:self
                                           action:@selector(showMenu:)];
}

- (UIBarButtonItem *)setupRightBarButton
{
    UIBarButtonItem *rightBarButtonItem = nil;
    if(!IS_IPAD())
    {
        rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing"]
                                                              style:UIBarButtonItemStylePlain
                                                             target:self
                                                             action:@selector(showPlayQueue:)];
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

#pragma mark Other

- (void)showDeleteToggles
{
    // Show the delete toggle for already visible cells
    [UIView animateWithDuration:.3 delay:0.0 options:UIViewAnimationOptionCurveEaseIn animations:^{
        for (UITableViewCell *cell in self.tableView.visibleCells)
        {
            if ([cell respondsToSelector:@selector(showDeleteCheckbox)])
            {
                [(id)cell showDeleteCheckbox];
            }
        }
    } completion:nil];
}

- (void)hideDeleteToggles
{
    // Hide the delete toggle for already visible cells
    //[UIView animateWithDuration:.1 animations:^{
        for (UITableViewCell *cell in self.tableView.visibleCells)
        {
            if ([cell respondsToSelector:@selector(hideDeleteCheckbox)])
            {
                [(id)cell hideDeleteCheckbox];
            }
        }
    //}];
}

- (void)markCellAsPlayingAtIndexPath:(NSIndexPath *)indexPath
{
    for (UITableViewCell *cell in self.tableView.visibleCells)
    {
        if ([cell isKindOfClass:[ItemUITableViewCell class]])
        {
            [(ItemUITableViewCell *)cell setPlaying:NO];
        }
    }
    
    if (indexPath)
    {
        UITableViewCell *cell = [self.tableView cellForRowAtIndexPath:indexPath];
        if ([cell isKindOfClass:[ItemUITableViewCell class]])
        {
            [(ItemUITableViewCell *)cell setPlaying:YES];
        }
    }
}

#pragma mark - Actions -

- (void)showMenu:(id)sender
{
    [self.sidePanelController showLeftPanelAnimated:YES];
}

- (void)showPlayQueue:(id)sender
{
    [self.sidePanelController showRightPanelAnimated:YES];
}

#pragma mark - Table View Delegate -

-(void)tableView:(UITableView *)tableView willDisplayCell:(UITableViewCell *)cell forRowAtIndexPath:(NSIndexPath *)indexPath
{
    // Remove seperator inset
    if ([cell respondsToSelector:@selector(setSeparatorInset:)]) {
        [cell setSeparatorInset:UIEdgeInsetsZero];
    }
    
    // Prevent the cell from inheriting the Table View's margin settings
    if ([cell respondsToSelector:@selector(setPreservesSuperviewLayoutMargins:)]) {
        [cell setPreservesSuperviewLayoutMargins:NO];
    }
    
    // Explictly set your cell's layout margins
    if ([cell respondsToSelector:@selector(setLayoutMargins:)]) {
        [cell setLayoutMargins:UIEdgeInsetsZero];
    }
}

@end
