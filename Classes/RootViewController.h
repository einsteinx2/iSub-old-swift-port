//
//  RootViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton, SearchOverlayViewController, LoadingScreen, Artist, EGORefreshTableHeaderView, FolderDropdownControl;

@interface RootViewController : UITableViewController <UISearchBarDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
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
	
	NSMutableArray *copyListOfArtists;
	
	NSMutableData *receivedData;

	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
	
	NSUInteger searchY;
	
	FolderDropdownControl *dropdown;
	
	//NSDictionary *folders;
}

@property(assign,getter=isReloading) BOOL reloading;

@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) UISearchBar *searchBar;

@property (nonatomic, retain) NSMutableArray *copyListOfArtists;

@property BOOL isSearching;

@property (nonatomic, retain) FolderDropdownControl *dropdown;

- (void) searchTableView;
- (void) doneSearching_Clicked:(id)sender;

@end
