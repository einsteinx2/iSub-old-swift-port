//
//  AllAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class iSubAppDelegate, ViewObjectsSingleton, SearchOverlayViewController, Album, MusicSingleton, DatabaseSingleton, SUSAllAlbumsDAO, EGORefreshTableHeaderView, LoadingScreen, SUSAllSongsDAO;

@interface AllAlbumsViewController : UITableViewController <UISearchBarDelegate, SUSLoaderDelegate> 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	SUSAllAlbumsDAO *dataModel;
	
	UIView *headerView;
	UIButton *reloadButton;
	UILabel *reloadLabel;
	UIImageView *reloadImage;
	UILabel *countLabel;
	UILabel *reloadTimeLabel;
	IBOutlet UISearchBar *searchBar;
	
	SearchOverlayViewController *searchOverlayView;
	BOOL letUserSelectRow;
	NSURL *url;
	
	BOOL isAllAlbumsLoading;
	NSInteger numberOfRows;
	
	NSArray *sectionInfo;
	
	BOOL isProcessingArtists;
		
	BOOL isSearching;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
}

@property (nonatomic, retain) SUSAllAlbumsDAO *dataModel;
@property (nonatomic, retain) SUSAllSongsDAO *allSongsDataModel;

@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) NSArray *sectionInfo;

@property (nonatomic, retain) LoadingScreen *loadingScreen;

- (void) addCount;

- (void) doneSearching_Clicked:(id)sender;

- (void)dataSourceDidFinishLoadingNewData;

- (void)showLoadingScreen;
- (void)hideLoadingScreen;

@end
