//
//  AllAlbumsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

@class iSubAppDelegate, ViewObjectsSingleton, SearchOverlayViewController, Album, MusicSingleton, DatabaseSingleton, SUSAllAlbumsDAO;

@interface AllAlbumsViewController : UITableViewController <UISearchBarDelegate> 
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
	
	BOOL isSearching;
}

@property (nonatomic, retain) SUSAllAlbumsDAO *dataModel;

@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) NSArray *sectionInfo;

- (void) addCount;

- (void) searchTableView;
- (void) doneSearching_Clicked:(id)sender;

@end
