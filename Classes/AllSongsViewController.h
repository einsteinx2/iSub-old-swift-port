//
//  AllSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class Song, Album, SUSAllSongsDAO, LoadingScreen, EGORefreshTableHeaderView;

@interface AllSongsViewController : UITableViewController <UISearchBarDelegate, SUSLoaderDelegate> 
{		
	UIButton *reloadButton;
	UILabel *reloadLabel;
	UIImageView *reloadImage;
	UILabel *countLabel;
	UILabel *reloadTimeLabel;
	IBOutlet UISearchBar *searchBar;
	
	BOOL letUserSelectRow;
	NSURL *url;
		
	NSInteger numberOfRows;
		
	BOOL isSearching;
		
	BOOL isProcessingArtists;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
	
	UIView *searchOverlay;
	UIButton *dismissButton;
}

@property (strong) SUSAllSongsDAO *dataModel;

@property (strong) UIView *headerView;
@property (strong) NSArray *sectionInfo;

@property (strong) LoadingScreen *loadingScreen;

- (void) addCount;

- (void) doneSearching_Clicked:(id)sender;

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(SUSLoader*)theLoader;

- (void)dataSourceDidFinishLoadingNewData;

- (void)showLoadingScreen;
- (void)hideLoadingScreen;

@end