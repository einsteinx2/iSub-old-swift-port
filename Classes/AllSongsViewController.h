//
//  AllSongsViewController.h
//  iSub
//
//  Created by Ben Baron on 3/30/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

@class iSubAppDelegate, SavedSettings, ViewObjectsSingleton, SearchOverlayViewController, Song, MusicSingleton, DatabaseSingleton, Album;

@interface AllSongsViewController : UITableViewController <UISearchBarDelegate> 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	SavedSettings *settings;
	
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
	
	BOOL isAllSongsLoading;
	
	NSInteger numberOfRows;
	
	NSArray *sectionInfo;
	
	BOOL didBeginSearching;
	
	NSMutableData *loadingData;
	
	NSUInteger iteration;
	NSUInteger albumCount;
	NSUInteger currentRow;
	Album *currentAlbum;
}

@property (nonatomic, retain) UIView *headerView;
@property (nonatomic, retain) NSArray *sectionInfo;

@property (nonatomic, retain) Album *currentAlbum;

- (NSArray *) createSectionInfo;
- (void) addCount;

- (void) searchTableView;
- (void) doneSearching_Clicked:(id)sender;

@end