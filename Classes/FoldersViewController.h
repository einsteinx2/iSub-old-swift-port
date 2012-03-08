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
{
		
	UIView *headerView;
	UILabel *countLabel;
	UILabel *reloadTimeLabel;
	IBOutlet UISearchBar *searchBar;
	UIButton *blockerButton;
	BOOL letUserSelectRow;
	
	BOOL isSearching;
	
	BOOL isCountShowing;

	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
	
	NSUInteger searchY;
	
	FolderDropdownControl *dropdown;
		
	SUSRootFoldersDAO *dataModel;
	
	UIView *searchOverlay;
	UIButton *dismissButton;
}

@property(assign,getter=isReloading) BOOL reloading;

@property (retain) UIView *headerView;
@property (retain) UISearchBar *searchBar;

//@property (retain) NSArray *indexes;
//@property (retain) NSArray *folders;
//@property (retain) NSMutableArray *foldersSearch;

@property BOOL isSearching;

@property (retain) FolderDropdownControl *dropdown;

@property (retain) SUSRootFoldersDAO *dataModel;

- (void) doneSearching_Clicked:(id)sender;

// Loader Delegate Methods
- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader*)theLoader;

// FolderDropdown Delegate Methods
- (void)folderDropdownMoveViewsY:(float)y;
- (void)folderDropdownSelectFolder:(NSNumber *)folderId;

@end
