//
//  AllAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class SearchOverlayViewController, Album, SUSAllAlbumsDAO, EGORefreshTableHeaderView, LoadingScreen, SUSAllSongsDAO;

@interface AllAlbumsViewController : UITableViewController <UISearchBarDelegate, SUSLoaderDelegate> 
{
	
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

@property (retain) SUSAllAlbumsDAO *dataModel;
@property (retain) SUSAllSongsDAO *allSongsDataModel;

@property (retain) UIView *headerView;
@property (retain) NSArray *sectionInfo;

@property (retain) LoadingScreen *loadingScreen;

- (void) addCount;

- (void) doneSearching_Clicked:(id)sender;

- (void)dataSourceDidFinishLoadingNewData;

- (void)showLoadingScreen;
- (void)hideLoadingScreen;

@end
