//
//  RootViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "LoaderDelegate.h"
#import "FolderDropdownDelegate.h"

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, SearchOverlayViewController, LoadingScreen, Artist, EGORefreshTableHeaderView, FolderDropdownControl, SavedSettings, SUSRootFoldersDAO;

@interface RootViewController : UITableViewController <UISearchBarDelegate, LoaderDelegate, FolderDropdownDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	
	SavedSettings *settings;
	
	UIView *headerView;
	UIView *folderDropdown;
	UILabel *folderDropdownLabel;
	CALayer *arrowImage;
	UILabel *countLabel;
	UILabel *reloadTimeLabel;
	IBOutlet UISearchBar *searchBar;
	
	LoadingScreen *allArtistsLoadingScreen;
	
	SearchOverlayViewController *searchOverlayView;
	BOOL letUserSelectRow;
	
	BOOL isSearching;
	
	BOOL isCountShowing;
	
	//NSArray *indexes;
	//NSArray *folders;
	//NSMutableArray *foldersSearch;
	
	//NSMutableData *receivedData;

	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
	
	NSUInteger searchY;
	
	FolderDropdownControl *dropdown;
	
	//NSDictionary *folders;
	
	SUSRootFoldersDAO *dataModel;
}

@property(assign,getter=isReloading) BOOL reloading;

@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) UISearchBar *searchBar;

//@property (nonatomic, retain) NSArray *indexes;
//@property (nonatomic, retain) NSArray *folders;
//@property (nonatomic, retain) NSMutableArray *foldersSearch;

@property BOOL isSearching;

@property (nonatomic, retain) FolderDropdownControl *dropdown;

@property (nonatomic, retain) SUSRootFoldersDAO *dataModel;

- (void) doneSearching_Clicked:(id)sender;

// Loader Delegate Methods
- (void)loadingFailed:(Loader*)loader;
- (void)loadingFinished:(Loader*)loader;

// FolderDropdown Delegate Methods
- (void)folderDropdownMoveViewsY:(float)y;
- (void)folderDropdownSelectFolder:(NSNumber *)folderId;

@end
