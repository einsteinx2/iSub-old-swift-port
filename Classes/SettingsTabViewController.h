//
//  SettingsTabViewController.h
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class SavedSettings, iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, SocialSingleton, DatabaseSingleton;

@interface SettingsTabViewController : UIViewController <UITextFieldDelegate>
{
	SavedSettings *settings;
	
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	SocialSingleton *socialControls;
	DatabaseSingleton *databaseControls;
	
	UIViewController *parentController;
	
	IBOutlet UILabel *versionLabel;
	
	IBOutlet UISwitch *manualOfflineModeSwitch;
	
	IBOutlet UISwitch *checkUpdatesSwitch;
	
	IBOutlet UISwitch *autoReloadArtistSwitch;
	
	IBOutlet UISwitch *disablePopupsSwitch;
	
	IBOutlet UISwitch *disableRotationSwitch;
	
	IBOutlet UISwitch *disableScreenSleepSwitch;
	
	IBOutlet UISwitch *enableBasicAuthSwitch;
	
	IBOutlet UISwitch *enableSongsTabSwitch;
	IBOutlet UILabel *enableSongsTabLabel;
	IBOutlet UILabel *enableSongsTabDesc;
	
	IBOutlet UISegmentedControl *recoverSegmentedControl;
	IBOutlet UISegmentedControl *maxBitrateWifiSegmentedControl;
	IBOutlet UISegmentedControl *maxBitrate3GSegmentedControl;
	
	IBOutlet UISwitch *enableLyricsSwitch;
	IBOutlet UISwitch *enableCacheStatusSwitch;
	IBOutlet UISwitch *autoPlayerInfoSwitch;
	
	IBOutlet UISwitch *enableSwipeSwitch;
	IBOutlet UISwitch *enableTapAndHoldSwitch;
	
	IBOutlet UISwitch *enableSongCachingSwitch;
	
	IBOutlet UILabel *enableNextSongCacheLabel;
	IBOutlet UISwitch *enableNextSongCacheSwitch;
	IBOutlet UILabel *enableNextSongPartialCacheLabel;
	IBOutlet UISwitch *enableNextSongPartialCacheSwitch;
	
	IBOutlet UISegmentedControl *cachingTypeSegmentedControl;
	
	unsigned long long int totalSpace;
	unsigned long long int freeSpace;
	IBOutlet UILabel *cacheSpaceLabel1;
	//IBOutlet UILabel *cacheSpaceLabel2;
	IBOutlet UITextField *cacheSpaceLabel2;
	IBOutlet UILabel *freeSpaceLabel;
	IBOutlet UILabel *totalSpaceLabel;
	IBOutlet UIView *totalSpaceBackground;
	IBOutlet UIView *freeSpaceBackground;
	IBOutlet UISlider *cacheSpaceSlider;
	IBOutlet UILabel *cacheSpaceDescLabel;
	
	IBOutlet UISwitch *autoDeleteCacheSwitch;
	IBOutlet UISegmentedControl *autoDeleteCacheTypeSegmentedControl;
	IBOutlet UISegmentedControl *cacheSongCellColorSegmentedControl;
	
	IBOutlet UIButton *twitterSigninButton;
	IBOutlet UILabel *twitterStatusLabel;
	IBOutlet UISwitch *twitterEnabledSwitch;
	
	IBOutlet UISwitch *enableScrobblingSwitch;
	IBOutlet UILabel *scrobblePercentLabel;
	IBOutlet UISlider *scrobblePercentSlider;
	
	IBOutlet UISegmentedControl *quickSkipSegmentControl;
	
	NSDate *loadedTime;
}

@property (retain) UIViewController *parentController;

@property (retain) NSDate *loadedTime;

- (void)toggleCacheControlsVisibility;
- (void)cachingTypeToggle;
- (IBAction)segmentAction:(id)sender;
- (IBAction)switchAction:(id)sender;
- (IBAction)updateMinFreeSpaceLabel;
- (IBAction)updateMinFreeSpaceSetting;
- (IBAction)revertMinFreeSpaceSlider;
- (IBAction)twitterButtonAction;
- (IBAction)updateScrobblePercentLabel;
- (IBAction)updateScrobblePercentSetting;
- (IBAction)resetFolderCacheAction;
- (IBAction)resetAlbumArtCacheAction;
- (void)textFieldDidChange:(UITextField *)textField;

- (void)popFoldersTab;
@end
