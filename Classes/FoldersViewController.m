//
//  FoldersViewController.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "FoldersViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "FolderViewController.h"
#import "ArtistUITableViewCell.h"
#import <QuartzCore/QuartzCore.h>
#import "FolderDropdownControl.h"
#import "UIViewController+PushViewControllerCustom.h"

@interface FoldersViewController() <UISearchBarDelegate, ISMSLoaderDelegate, FolderDropdownDelegate>
{
    SUSRootFoldersDAO *_dataModel;
    
    BOOL _reloading;
    BOOL _letUserSelectRow;
    BOOL _searching;
    BOOL _countShowing;
    
    UIView *_headerView;
    UISearchBar *_searchBar;
    UILabel *_countLabel;
    UILabel *_reloadTimeLabel;
    UIButton *_blockerButton;
    UIView *_searchOverlay;
    UIButton *_dismissButton;
    FolderDropdownControl *_dropdown;
}
- (void)dataSourceDidFinishLoadingNewData;
- (void)addCount;
- (void)loadData:(NSNumber *)folderId;
@end

@implementation FoldersViewController

#pragma mark - Lifecycle -

- (void)createDataModel
{
	_dataModel = [[SUSRootFoldersDAO alloc] initWithDelegate:self];
	_dataModel.selectedFolderId = [settingsS rootFoldersSelectedFolderId];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	[self createDataModel];
	
	self.title = @"Folders";
		
	_letUserSelectRow = YES;
	
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverSwitched:) name:ISMSNotification_ServerSwitched object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFolders:) name:ISMSNotification_ServerCheckPassed object:nil];
    
    // Hide the folder selector when there is only one folder
	if (!IS_IPAD())
	{
        CGPoint contentOffset;
		if ([_dropdown.folders count] <= 2)
			contentOffset = CGPointMake(0, 86);
		else
            contentOffset = CGPointMake(0, 50);
        
        [self.tableView setContentOffset:contentOffset animated:NO];
	}
		
    // Add the count if we've cached the folder data already
	if ([_dataModel isRootFolderIdCached])
    {
		[self addCount];
    }
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    
    // Load data if it's not cached yet and we're not processing the Artists/Albums/Songs tabs
	if (![SUSAllSongsLoader isLoading] && !viewObjectsS.isArtistsLoading && ![_dataModel isRootFolderIdCached])
	{
		[self loadData:[settingsS rootFoldersSelectedFolderId]];
	}
	
	[Flurry logEvent:@"FoldersTab"];
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];

	_dataModel.delegate = nil;
	_dropdown.delegate = nil;
}

#pragma mark - Loading -

- (BOOL)shouldSetupRefreshControl
{
    return YES;
}

- (void)didPullToRefresh
{
    if (!_reloading)
    {
        _reloading = YES;
        [self loadData:[settingsS rootFoldersSelectedFolderId]];
    }
}

- (void)dataSourceDidFinishLoadingNewData
{
    _reloading = NO;
    [self.refreshControl endRefreshing];
}

- (void)updateCount
{
	if (_dataModel.count == 1)
		_countLabel.text = [NSString stringWithFormat:@"%lu Folder", (unsigned long)_dataModel.count];
	else
		_countLabel.text = [NSString stringWithFormat:@"%lu Folders", (unsigned long)_dataModel.count];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	[formatter setDateStyle:NSDateFormatterMediumStyle];
	[formatter setTimeStyle:NSDateFormatterShortStyle];
	_reloadTimeLabel.text = [NSString stringWithFormat:@"last reload: %@", [formatter stringFromDate:[settingsS rootFoldersReloadTime]]];
}

- (void)removeCount
{
	self.tableView.tableHeaderView = nil;
	_countShowing = NO;
}

- (void)addCount
{	
	_countShowing = YES;
	
	_headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 126)];
	_headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_headerView.backgroundColor = ISMSHeaderColor;
	
    // This is a hack to prevent unwanted taps in the header, but it messes with voice over
	if (!UIAccessibilityIsVoiceOverRunning())
    {
        _blockerButton = [UIButton buttonWithType:UIButtonTypeCustom];
        _blockerButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
        _blockerButton.frame = _headerView.frame;
        [_headerView addSubview:_blockerButton];
    }
	
	_countLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 5, 320, 30)];
	_countLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_countLabel.backgroundColor = [UIColor clearColor];
	_countLabel.textColor = ISMSHeaderTextColor;
	_countLabel.textAlignment = NSTextAlignmentCenter;
	_countLabel.font = ISMSBoldFont(30);
	[_headerView addSubview:_countLabel];
	
	_reloadTimeLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 36, 320, 12)];
	_reloadTimeLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_reloadTimeLabel.backgroundColor = [UIColor clearColor];
	_reloadTimeLabel.textColor = ISMSHeaderTextColor;
	_reloadTimeLabel.textAlignment = NSTextAlignmentCenter;
	_reloadTimeLabel.font = ISMSRegularFont(11);
	[_headerView addSubview:_reloadTimeLabel];
	
	_searchBar = [[UISearchBar  alloc] initWithFrame:CGRectMake(0, 86, 320, 40)];
	_searchBar.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	_searchBar.delegate = self;
	_searchBar.autocorrectionType = UITextAutocorrectionTypeNo;
	_searchBar.placeholder = @"Folder name";
	[_headerView addSubview:_searchBar];
	
	_dropdown = [[FolderDropdownControl alloc] initWithFrame:CGRectMake(50, 53, 220, 30)];
	_dropdown.delegate = self;
	NSDictionary *dropdownFolders = [SUSRootFoldersDAO folderDropdownFolders];
	if (dropdownFolders != nil)
	{
		_dropdown.folders = dropdownFolders;
	}
	else
	{
		_dropdown.folders = [NSDictionary dictionaryWithObject:@"All Folders" forKey:@-1];
	}
	[_dropdown selectFolderWithId:_dataModel.selectedFolderId];
	
	[_headerView addSubview:_dropdown];
	
	[self updateCount];
    
    // Special handling for voice over users
    if (UIAccessibilityIsVoiceOverRunning())
    {
        // Add a refresh button
        UIButton *voiceOverRefresh = [UIButton buttonWithType:UIButtonTypeCustom];
        voiceOverRefresh.frame = CGRectMake(0, 0, 50, 50);
        [voiceOverRefresh addTarget:self action:@selector(a_reload:) forControlEvents:UIControlEventTouchUpInside];
        voiceOverRefresh.accessibilityLabel = @"Reload Folders";
        [_headerView addSubview:voiceOverRefresh];
        
        // Resize the two labels at the top so the refresh button can be pressed
        _countLabel.frame = CGRectMake(50, 5, 220, 30);
        _reloadTimeLabel.frame = CGRectMake(50, 36, 220, 12);
    }
	
	self.tableView.tableHeaderView = _headerView;
}

- (void)cancelLoad
{
	[_dataModel cancelLoad];
	[viewObjectsS hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];
}

- (void)loadData:(NSNumber *)folderId
{
	[_dropdown updateFolders];
	
	viewObjectsS.isArtistsLoading = YES;
	
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	
	_dataModel.selectedFolderId = folderId;
	[_dataModel startLoad];
}

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{	
	viewObjectsS.isArtistsLoading = NO;
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
	
	// Inform the user that the connection failed.
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error loading the artist list.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{	
	if (_countShowing)
		[self updateCount];
	else
		[self addCount];		
	
	[self.tableView reloadData];
	
	if (!IS_IPAD())
		self.tableView.backgroundColor = [UIColor clearColor];
	
	viewObjectsS.isArtistsLoading = NO;
	
	// Hide the loading screen
	[viewObjectsS hideLoadingScreen];
	
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - Folder Dropdown Delegate -

- (void)folderDropdownMoveViewsY:(float)y
{
	self.tableView.tableHeaderView.height += y;
	_searchBar.y += y;
	_blockerButton.frame = self.tableView.tableHeaderView.frame;
	
	self.tableView.tableHeaderView = self.tableView.tableHeaderView;
}

- (void)folderDropdownViewsFinishedMoving
{

}

- (void)folderDropdownSelectFolder:(NSNumber *)folderId
{
	[_dropdown selectFolderWithId:folderId];
	 
	// Save the default
	settingsS.rootFoldersSelectedFolderId = folderId;
	
	// Reload the data
	_dataModel.selectedFolderId = folderId;
	_searching = NO;
	if ([_dataModel isRootFolderIdCached])
	{
		[self.tableView reloadData];
		[self updateCount];
	}
	else
	{
		[self loadData:folderId];
	}
}

#pragma mark - Notifications -

- (void)serverSwitched:(NSNotification *)notification
{
	[self createDataModel];
	if (![_dataModel isRootFolderIdCached])
	{
		[self.tableView reloadData];
		[self removeCount];
	}
		
	[self folderDropdownSelectFolder:@-1];
}

- (void)updateFolders:(NSNotification *)notification
{
	[_dropdown updateFolders];
}

#pragma mark - Actions -

- (void)a_reload:(id)sender
{
	if (![SUSAllSongsLoader isLoading])
	{
		[self loadData:[settingsS rootFoldersSelectedFolderId]];
	}
	else
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Please Wait"
                                                                    message:@"You cannot reload the Artists tab while the Albums or Songs tabs are loading"
                                                                   delegate:self
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
		[alert show];
	}
}


#pragma mark - Search Bar -

- (void)createSearchOverlay
{
	_searchOverlay = [[UIView alloc] init];
	_searchOverlay.frame = CGRectMake(0, 0, 480, 480);
	_searchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_searchOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	_searchOverlay.alpha = 0.0;
	self.tableView.tableFooterView = _searchOverlay;
	
	_dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[_dismissButton addTarget:self action:@selector(a_doneSearching:) forControlEvents:UIControlEventTouchUpInside];
	_dismissButton.frame = self.view.bounds;
	_dismissButton.enabled = NO;
	[_searchOverlay addSubview:_dismissButton];
	
	// Animate the search overlay on screen
    [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        _searchOverlay.alpha = 1;
        _dismissButton.enabled = YES;
    } completion:nil];
}

- (void)hideSearchOverlay
{
	if (_searchOverlay)
	{
		// Animate the search overlay off screen
        [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
            _searchOverlay.alpha = 0;
            _dismissButton.enabled = NO;
        } completion:^(BOOL finished) {
            [_searchOverlay removeFromSuperview];
            _searchOverlay = nil;
            if (!self.tableView.tableFooterView) self.tableView.tableFooterView = [[UIView alloc] init];
        }];
	}
}

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar
{
	if (_searching)
		return;
	
	// Remove the index bar
	_searching = YES;
	[_dataModel clearSearchTable];
	[self.tableView reloadData];
	
	[_dropdown closeDropdownFast];
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
	
	if ([theSearchBar.text length] == 0)
	{
		[self createSearchOverlay];
				
		_letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
	}
	
	//Add the done button.
	self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                          target:self
                                                                                          action:@selector(a_doneSearching:)];
}

- (void)searchBar:(UISearchBar *)theSearchBar textDidChange:(NSString *)searchText
{
	if([searchText length] > 0) 
	{				
		[self hideSearchOverlay];
		
		_letUserSelectRow = YES;
		self.tableView.scrollEnabled = YES;
		
		[_dataModel searchForFolderName:_searchBar.text];
		
		[self.tableView reloadData];
	}
	else 
	{		
		[self createSearchOverlay];
				
		_letUserSelectRow = NO;
		self.tableView.scrollEnabled = NO;
		
		[_dataModel clearSearchTable];
		
		[self.tableView reloadData];
		
		[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
	}
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar 
{
	[_searchBar resignFirstResponder];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar
{
	[self hideSearchOverlay];
}

- (void)a_doneSearching:(id)sender
{
	[self updateCount];
	
	_searchBar.text = @"";
	[_searchBar resignFirstResponder];
	
	_letUserSelectRow = YES;
	_searching = NO;
	self.navigationItem.leftBarButtonItem = nil;
	self.tableView.scrollEnabled = YES;
	
	[self hideSearchOverlay];
	
	[_dataModel clearSearchTable];
	
	[self.tableView reloadData];
	
	[self.tableView setContentOffset:CGPointMake(0, 86) animated:YES];
}

#pragma mark - TableView -

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{	
	if (_searching)
	{
		return 1;
	}
	else
	{
		NSUInteger count = [[_dataModel indexNames] count];
		return count;
	}
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
	if (_searching)
	{
		NSUInteger count = _dataModel.searchCount;
		return count;
	}
	else 
	{
		if ([[_dataModel indexCounts] count] > section)
		{
			NSUInteger count = [[[_dataModel indexCounts] objectAtIndexSafe:section] intValue];
			return count;
		}
		
		return 0;
	}
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{	
	static NSString *cellIdentifier = @"ArtistCell";
	ArtistUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[ArtistUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
	}

	ISMSArtist *anArtist = nil;
	if(_searching)
	{
		anArtist = [_dataModel artistForPositionInSearch:(indexPath.row + 1)];
	}
	else
	{
		if ([[_dataModel indexPositions] count] > indexPath.section)
		{
			NSUInteger sectionStartIndex = [[[_dataModel indexPositions] objectAtIndexSafe:indexPath.section] intValue];
			anArtist = [_dataModel artistForPosition:(sectionStartIndex + indexPath.row)];
		}
	}
	cell.myArtist = anArtist;
	
	[cell.artistNameLabel setText:anArtist.name];
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
	return cell;
}

- (NSString *)tableView:(UITableView *)tableView titleForHeaderInSection:(NSInteger)section 
{	
	if(_searching)
		return @"";
	
	if ([[_dataModel indexNames] count] == 0)
		return @"";
	
	NSString *title = [[_dataModel indexNames] objectAtIndexSafe:section];

	return title;
}

- (NSArray *)sectionIndexTitlesForTableView:(UITableView *)tableView
{
	if(_searching)
		return nil;
	
	NSMutableArray *titles = [NSMutableArray arrayWithCapacity:0];
	[titles addObject:@"{search}"];
	[titles addObjectsFromArray:[_dataModel indexNames]];
		
	return titles;
}

- (NSInteger)tableView:(UITableView *)tableView sectionForSectionIndexTitle:(NSString *)title atIndex:(NSInteger)index 
{
	if(_searching)
		return -1;
	
	if (index == 0) 
	{
		if (_dropdown.folders == nil || [_dropdown.folders count] == 2)
			[self.tableView setContentOffset:CGPointMake(0, 86) animated:NO];
		else
			[self.tableView setContentOffset:CGPointMake(0, 50) animated:NO];
		
		return -1;
	}
	
	return index - 1;
}

- (NSIndexPath *)tableView :(UITableView *)theTableView willSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if(_letUserSelectRow)
		return indexPath;
	else
		return nil;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled)
	{
		ISMSArtist *anArtist = nil;
		if(_searching)
		{
			anArtist = [_dataModel artistForPositionInSearch:(indexPath.row + 1)];
		}
		else 
		{	
			if ([[_dataModel indexPositions] count] > indexPath.section)
			{
				NSUInteger sectionStartIndex = [[[_dataModel indexPositions] objectAtIndexSafe:indexPath.section] intValue];
				anArtist = [_dataModel artistForPosition:(sectionStartIndex + indexPath.row)];
			}
		}
		FolderViewController* albumViewController = [[FolderViewController alloc] initWithArtist:anArtist orAlbum:nil];
		[self pushViewControllerCustom:albumViewController];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

@end

