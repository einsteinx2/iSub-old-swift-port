//
//  RootViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "LoaderDelegate.h"

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, SearchOverlayViewController, LoadingScreen, Artist, EGORefreshTableHeaderView, FolderDropdownControl, DefaultSettings;

@interface RootViewController : UITableViewController <UISearchBarDelegate, LoaderDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	
	DefaultSettings *settings;
	
	UIView *headerView;
	UIView *folderDropdown;
	UILabel *folderDropdownLabel;
	CALayer *arrowImage;
	UILabel *countLabel;
	UILabel *reloadTimeLabel;
	IBOutlet UISearchBar *searchBar;
	
	LoadingScreen *allArtistsLoadingScreen;
	
	SearchOverlayViewController *searchOverlayView;
	BOOL searching;
	BOOL letUserSelectRow;
	BOOL didBeginSearching;
	
	BOOL isSearching;
	
	BOOL isCountShowing;
	
	NSArray *indexes;
	NSArray *folders;
	NSMutableArray *foldersSearch;
	
	//NSMutableData *receivedData;

	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
	
	NSUInteger searchY;
	
	FolderDropdownControl *dropdown;
	
	//NSDictionary *folders;
}

@property(assign,getter=isReloading) BOOL reloading;

@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) UISearchBar *searchBar;

@property (nonatomic, retain) NSArray *indexes;
@property (nonatomic, retain) NSArray *folders;
@property (nonatomic, retain) NSMutableArray *foldersSearch;

@property BOOL isSearching;

@property (nonatomic, retain) FolderDropdownControl *dropdown;

- (void) searchTableView;
- (void) doneSearching_Clicked:(id)sender;

// Loader Delegate Methods
- (void)loadingFailed:(Loader*)loader;
- (void)loadingFinished:(Loader*)loader;

@end
