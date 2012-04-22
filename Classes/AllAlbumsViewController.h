//
//  AllAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class Album, SUSAllAlbumsDAO, EGORefreshTableHeaderView, LoadingScreen, SUSAllSongsDAO;

@interface AllAlbumsViewController : UITableViewController <UISearchBarDelegate, SUSLoaderDelegate> 
{	
	UIButton *reloadButton;
	UILabel *reloadLabel;
	UIImageView *reloadImage;
	UILabel *countLabel;
	UILabel *reloadTimeLabel;
	IBOutlet UISearchBar *searchBar;
	
	BOOL letUserSelectRow;
	NSURL *url;
	
	BOOL isAllAlbumsLoading;
	NSInteger numberOfRows;
		
	BOOL isProcessingArtists;
		
	BOOL isSearching;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
	
	UIView *searchOverlay;
	UIButton *dismissButton;
}

@property (strong) SUSAllAlbumsDAO *dataModel;
@property (strong) SUSAllSongsDAO *allSongsDataModel;

@property (strong) UIView *headerView;
@property (strong) NSArray *sectionInfo;

@property (strong) LoadingScreen *loadingScreen;

- (void) addCount;

- (void) doneSearching_Clicked:(id)sender;

- (void)dataSourceDidFinishLoadingNewData;

- (void)showLoadingScreen;
- (void)hideLoadingScreen;

@end
