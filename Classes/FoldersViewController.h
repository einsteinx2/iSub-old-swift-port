//
//  RootViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "FolderDropdownDelegate.h"

@class Artist, EGORefreshTableHeaderView, FolderDropdownControl, SUSRootFoldersDAO;

@interface FoldersViewController : UITableViewController <UISearchBarDelegate, SUSLoaderDelegate, FolderDropdownDelegate>

@property BOOL letUserSelectRow;
@property BOOL isSearching;
@property BOOL isCountShowing;

@property (strong) EGORefreshTableHeaderView *refreshHeaderView;
@property (assign, getter=isReloading) BOOL reloading;

@property (strong) UIView *headerView;
@property (strong) UISearchBar *searchBar;
@property (strong) UILabel *countLabel;
@property (strong) UILabel *reloadTimeLabel;
@property (strong) UIButton *blockerButton;

@property NSUInteger searchY;
@property (strong) UIView *searchOverlay;
@property (strong) UIButton *dismissButton;

@property (strong) FolderDropdownControl *dropdown;

@property (strong) SUSRootFoldersDAO *dataModel;

- (void) doneSearching_Clicked:(id)sender;

// Loader Delegate Methods
- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader*)theLoader;

// FolderDropdown Delegate Methods
- (void)folderDropdownMoveViewsY:(float)y;
- (void)folderDropdownSelectFolder:(NSNumber *)folderId;

@end
