//
//  SettingsTabViewController.m
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SettingsTabViewController.h"
#import <Accounts/Accounts.h>
#import <Social/Social.h>
#import "iSub-Swift.h"

@interface SettingsTabViewController() <UITextFieldDelegate>
@property (nonatomic, strong) IBOutlet UILabel *versionLabel;
@property (nonatomic, strong) IBOutlet UISwitch *disableScreenSleepSwitch;
@property (nonatomic, strong) IBOutlet UISwitch *disableCellUsageSwitch;
@property (nonatomic, strong) IBOutlet UISegmentedControl *maxBitRateWifiSegmentedControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *maxBitRate3GSegmentedControl;
@property (nonatomic, strong) IBOutlet UILabel *enableManualCachingOnWWANLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableManualCachingOnWWANSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableSongCachingLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableSongCachingSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableNextSongCacheLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableNextSongCacheSwitch;
@property (nonatomic, strong) IBOutlet UILabel *enableBackupCacheLabel;
@property (nonatomic, strong) IBOutlet UISwitch *enableBackupCacheSwitch;
@property (nonatomic, strong) IBOutlet UISegmentedControl *cachingTypeSegmentedControl;
@property (nonatomic) unsigned long long int totalSpace;
@property (nonatomic) unsigned long long int freeSpace;
@property (nonatomic) IBOutlet UILabel *cacheSpaceLabel1;
@property (nonatomic, strong) IBOutlet UITextField *cacheSpaceLabel2;
@property (nonatomic, strong) IBOutlet UILabel *freeSpaceLabel;
@property (nonatomic, strong) IBOutlet UILabel *totalSpaceLabel;
@property (nonatomic, strong) IBOutlet UIView *totalSpaceBackground;
@property (nonatomic, strong) IBOutlet UIView *freeSpaceBackground;
@property (nonatomic, strong) IBOutlet UISlider *cacheSpaceSlider;
@property (nonatomic, strong) IBOutlet UISwitch *autoDeleteCacheSwitch;
@property (nonatomic, strong) IBOutlet UISegmentedControl *autoDeleteCacheTypeSegmentedControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *quickSkipSegmentControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *maxVideoBitRateWifiSegmentedControl;
@property (nonatomic, strong) IBOutlet UISegmentedControl *maxVideoBitRate3GSegmentedControl;
@property (nonatomic, strong) NSDate *loadedTime;

@property (nonatomic, strong) IBOutletCollection(UISwitch) NSArray *switches;

- (IBAction)segmentAction:(id)sender;
- (IBAction)switchAction:(id)sender;
- (IBAction)updateMinFreeSpaceLabel;
- (IBAction)updateMinFreeSpaceSetting;
@end

@implementation SettingsTabViewController

- (BOOL)shouldAutorotate
{
    return YES;
}

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	// Fix for UISwitch/UISegment bug in iOS 4.3 beta 1 and 2
	//
	self.loadedTime = [NSDate date];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(reloadTwitterUIElements) name:@"twitterAuthenticated" object:nil];
	
	// Set version label
	NSString *version = [[[NSBundle mainBundle] infoDictionary] objectForKey:(NSString*)kCFBundleVersionKey];
#if DEBUG
	NSString *build = [[[NSBundle mainBundle] infoDictionary] objectForKey:@"CFBundleShortVersionString"];
	self.versionLabel.text = [NSString stringWithFormat:@"iSub version %@ build %@", build, version];
#else
	self.versionLabel.text = [NSString stringWithFormat:@"iSub version %@", version];
#endif
    
    self.disableCellUsageSwitch.on = SavedSettings.si.isDisableUsageOver3G;
		
	self.maxBitRateWifiSegmentedControl.selectedSegmentIndex = SavedSettings.si.maxBitRateWifi;
	self.maxBitRate3GSegmentedControl.selectedSegmentIndex = SavedSettings.si.maxBitRate3G;
				
	// Cache Settings
    self.enableManualCachingOnWWANSwitch.on = SavedSettings.si.isManualCachingOnWWANEnabled;
	self.enableSongCachingSwitch.on = SavedSettings.si.isAutoSongCachingEnabled;
    self.enableBackupCacheSwitch.on = SavedSettings.si.isBackupCacheEnabled;
		
	self.totalSpace = CacheManager.si.totalSpace;
	self.freeSpace = CacheManager.si.freeSpace;
	self.freeSpaceLabel.text = [NSString stringWithFormat:@"Free space: %@", [NSString formatFileSize:self.freeSpace]];
	self.totalSpaceLabel.text = [NSString stringWithFormat:@"Total space: %@", [NSString formatFileSize:self.totalSpace]];
	float percentFree = (float) self.freeSpace / (float) self.totalSpace;
	CGRect frame = self.freeSpaceBackground.frame;
	frame.size.width = frame.size.width * percentFree;
	self.freeSpaceBackground.frame = frame;
	//self.cachingTypeSegmentedControl.selectedSegmentIndex = SavedSettings.si.cachingType;
	[self toggleCacheControlsVisibility];
	[self cachingTypeToggle];
	
	self.autoDeleteCacheSwitch.on = SavedSettings.si.isAutoDeleteCacheEnabled;
	
	self.autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex = SavedSettings.si.autoDeleteCacheType;
		
	switch (SavedSettings.si.quickSkipNumberOfSeconds) 
	{
		case 5: self.quickSkipSegmentControl.selectedSegmentIndex = 0; break;
		case 15: self.quickSkipSegmentControl.selectedSegmentIndex = 1; break;
		case 30: self.quickSkipSegmentControl.selectedSegmentIndex = 2; break;
		case 45: self.quickSkipSegmentControl.selectedSegmentIndex = 3; break;
		case 60: self.quickSkipSegmentControl.selectedSegmentIndex = 4; break;
		case 120: self.quickSkipSegmentControl.selectedSegmentIndex = 5; break;
		case 300: self.quickSkipSegmentControl.selectedSegmentIndex = 6; break;
		case 600: self.quickSkipSegmentControl.selectedSegmentIndex = 7; break;
		case 1200: self.quickSkipSegmentControl.selectedSegmentIndex = 8; break;
		default: break;
	}
	
	[self.cacheSpaceLabel2 addTarget:self action:@selector(textFieldDidChange:) forControlEvents:UIControlEventEditingChanged];
    
    self.maxVideoBitRate3GSegmentedControl.selectedSegmentIndex = SavedSettings.si.maxVideoBitRate3G;
    self.maxVideoBitRateWifiSegmentedControl.selectedSegmentIndex = SavedSettings.si.maxVideoBitRateWifi;
    
    // Fix switch positions for iOS 7
    for (UISwitch *sw in self.switches)
    {
        CGRect swFrame = sw.frame;
        swFrame.origin.x += 5;
        sw.frame = swFrame;
    }
    CGRect autoDeleteCacheSwitchFrame = self.autoDeleteCacheSwitch.frame;
    autoDeleteCacheSwitchFrame.origin.x -= 10;
    self.autoDeleteCacheSwitch.frame = autoDeleteCacheSwitchFrame;
}

- (void)cachingTypeToggle
{
	if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		self.cacheSpaceLabel1.text = @"Minimum free space:";
        //self.cacheSpaceLabel2.text = [settings formatFileSize:[[AppDelegate.si.settingsDictionary objectForKey:@"minFreeSpace"] unsignedLongLongValue]];
		self.cacheSpaceLabel2.text = [NSString formatFileSize:SavedSettings.si.minFreeSpace];
		//self.cacheSpaceSlider.value = [[AppDelegate.si.settingsDictionary objectForKey:@"minFreeSpace"] floatValue] / totalSpace;
		self.cacheSpaceSlider.value = (float)SavedSettings.si.minFreeSpace / self.totalSpace;
	}
	else if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		self.cacheSpaceLabel1.text = @"Maximum cache size:";
		//self.cacheSpaceLabel2.text = [settings formatFileSize:[[AppDelegate.si.settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue]];
		self.cacheSpaceLabel2.text = [NSString formatFileSize:SavedSettings.si.maxCacheSize];
		//self.cacheSpaceSlider.value = [[AppDelegate.si.settingsDictionary objectForKey:@"maxCacheSize"] floatValue] / totalSpace;
		self.cacheSpaceSlider.value = (float)SavedSettings.si.maxCacheSize / self.totalSpace;
	}
}

- (IBAction)segmentAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:self.loadedTime] > 0.5)
	{
		if (sender == self.maxBitRateWifiSegmentedControl)
		{
			SavedSettings.si.maxBitRateWifi = self.maxBitRateWifiSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.maxBitRate3GSegmentedControl)
		{
			SavedSettings.si.maxBitRate3G = self.maxBitRate3GSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.cachingTypeSegmentedControl)
		{
			//SavedSettings.si.cachingType = self.cachingTypeSegmentedControl.selectedSegmentIndex;
			//[self cachingTypeToggle];
		}
		else if (sender == self.autoDeleteCacheTypeSegmentedControl)
		{
			SavedSettings.si.autoDeleteCacheType = self.autoDeleteCacheTypeSegmentedControl.selectedSegmentIndex;
		}
		else if (sender == self.quickSkipSegmentControl)
		{
			switch (self.quickSkipSegmentControl.selectedSegmentIndex) 
			{
				case 0: SavedSettings.si.quickSkipNumberOfSeconds = 5; break;
				case 1: SavedSettings.si.quickSkipNumberOfSeconds = 15; break;
				case 2: SavedSettings.si.quickSkipNumberOfSeconds = 30; break;
				case 3: SavedSettings.si.quickSkipNumberOfSeconds = 45; break;
				case 4: SavedSettings.si.quickSkipNumberOfSeconds = 60; break;
				case 5: SavedSettings.si.quickSkipNumberOfSeconds = 120; break;
				case 6: SavedSettings.si.quickSkipNumberOfSeconds = 300; break;
				case 7: SavedSettings.si.quickSkipNumberOfSeconds = 600; break;
				case 8: SavedSettings.si.quickSkipNumberOfSeconds = 1200; break;
				default: break;
			}
		}
        else if (sender == self.maxVideoBitRate3GSegmentedControl)
        {
            SavedSettings.si.maxVideoBitRate3G = self.maxVideoBitRate3GSegmentedControl.selectedSegmentIndex;
        }
        else if (sender == self.maxVideoBitRateWifiSegmentedControl)
        {
            SavedSettings.si.maxVideoBitRateWifi = self.maxVideoBitRateWifiSegmentedControl.selectedSegmentIndex;
        }
	}
}

- (void)toggleCacheControlsVisibility
{
	if (self.enableSongCachingSwitch.on)
	{
		self.enableNextSongCacheLabel.alpha = 1;
		self.enableNextSongCacheSwitch.enabled = YES;
		self.enableNextSongCacheSwitch.alpha = 1;
		self.cachingTypeSegmentedControl.enabled = YES;
		self.cachingTypeSegmentedControl.alpha = 1;
		self.cacheSpaceLabel1.alpha = 1;
		self.cacheSpaceLabel2.alpha = 1;
		self.freeSpaceLabel.alpha = 1;
		self.totalSpaceLabel.alpha = 1;
		self.totalSpaceBackground.alpha = .7;
		self.freeSpaceBackground.alpha = .7;
		self.cacheSpaceSlider.enabled = YES;
		self.cacheSpaceSlider.alpha = 1;
    }
	else
	{
		self.enableNextSongCacheLabel.alpha = .5;
		self.enableNextSongCacheSwitch.enabled = NO;
		self.enableNextSongCacheSwitch.alpha = .5;
		self.cachingTypeSegmentedControl.enabled = NO;
		self.cachingTypeSegmentedControl.alpha = .5;
		self.cacheSpaceLabel1.alpha = .5;
		self.cacheSpaceLabel2.alpha = .5;
		self.freeSpaceLabel.alpha = .5;
		self.totalSpaceLabel.alpha = .5;
		self.totalSpaceBackground.alpha = .3;
		self.freeSpaceBackground.alpha = .3;
		self.cacheSpaceSlider.enabled = NO;
		self.cacheSpaceSlider.alpha = .5;
	}
}

- (IBAction)switchAction:(id)sender
{
	if ([[NSDate date] timeIntervalSinceDate:self.loadedTime] > 0.5)
	{
		if (sender == self.enableManualCachingOnWWANSwitch)
        {
            if (self.enableManualCachingOnWWANSwitch.on)
            {
                // Prompt the warning
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"This feature can use a large amount of data. Please be sure to monitor your data plan usage to avoid overage charges from your wireless provider." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                alert.tag = 2;
                [alert show];
            }
            else
            {
                SavedSettings.si.isManualCachingOnWWANEnabled = NO;
            }
        }
		else if (sender == self.enableSongCachingSwitch)
		{
			SavedSettings.si.isAutoSongCachingEnabled = self.enableSongCachingSwitch.on;
			[self toggleCacheControlsVisibility];
		}
		else if (sender == self.enableNextSongCacheSwitch)
		{
			SavedSettings.si.isNextSongCacheEnabled = self.enableNextSongCacheSwitch.on;
			[self toggleCacheControlsVisibility];
		}
        else if (sender == self.enableBackupCacheSwitch)
		{
            if (self.enableBackupCacheSwitch.on)
            {
                // Prompt the warning
                UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Warning" message:@"This setting can take up a large amount of space on your computer or iCloud storage. Are you sure you want to backup your cached songs?" delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
                alert.tag = 4;
                [alert show];
            }
            else
            {
                SavedSettings.si.isBackupCacheEnabled = NO;
            }
		}
		else if (sender == self.autoDeleteCacheSwitch)
		{
			SavedSettings.si.isAutoDeleteCacheEnabled = self.autoDeleteCacheSwitch.on;
		}
		else if (sender == self.disableScreenSleepSwitch)
		{
			SavedSettings.si.isScreenSleepEnabled = !self.disableScreenSleepSwitch.on;
			[UIApplication sharedApplication].idleTimerDisabled = self.disableScreenSleepSwitch.on;
		}
        else if (sender == self.disableCellUsageSwitch)
        {
            SavedSettings.si.isDisableUsageOver3G = self.disableCellUsageSwitch.on;
            
            if (!SavedSettings.si.isOfflineMode && SavedSettings.si.isDisableUsageOver3G && !AppDelegate.si.networkStatus.isReachableWifi)
            {
                // We're on 3G and we just disabled use on 3G, so go offline
                [AppDelegate.si enterOfflineModeForce];
            }
            else if (SavedSettings.si.isOfflineMode && !SavedSettings.si.isDisableUsageOver3G && !AppDelegate.si.networkStatus.isReachableWifi)
            {
                // We're on 3G and we just enabled use on 3G, so go online if we're offline
                [AppDelegate.si enterOfflineModeForce];
            }
        }
	}
}

- (IBAction)resetAlbumArtCacheAction
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Reset Album Art Cache" message:@"Are you sure you want to do this? This will clear all saved album art." delegate:self cancelButtonTitle:@"Cancel" otherButtonTitles:@"OK", nil];
	alert.tag = 1;
	[alert show];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if (alertView.tag == 0 && buttonIndex == 1)
	{
		[LoadingScreen showLoadingScreenOnMainWindowWithMessage:@"Processing"];
		[self performSelector:@selector(resetFolderCache) withObject:nil afterDelay:0.05];
	}
	else if (alertView.tag == 1 && buttonIndex == 1)
	{
		[LoadingScreen showLoadingScreenOnMainWindowWithMessage:@"Processing"];
		[self performSelector:@selector(resetAlbumArtCache) withObject:nil afterDelay:0.05];
	}
    else if (alertView.tag == 2)
    {
        if (buttonIndex == 0)
        {
            // They canceled, turn off the switch
            [self.enableManualCachingOnWWANSwitch setOn:NO animated:YES];
        }
        else
        {
            SavedSettings.si.isManualCachingOnWWANEnabled = YES;
        }
    }
    else if (alertView.tag == 4)
    {
        if (buttonIndex == 0)
        {
            [self.enableBackupCacheSwitch setOn:NO animated:YES];
        }
        else
        {
            SavedSettings.si.isBackupCacheEnabled = YES;
        }
    }
}

- (void)updateCacheSpaceSlider
{
	self.cacheSpaceSlider.value = ((double)[self.cacheSpaceLabel2.text fileSizeFromFormat] / (double)self.totalSpace);
}

- (IBAction)updateMinFreeSpaceLabel
{
	self.cacheSpaceLabel2.text = [NSString formatFileSize:(unsigned long long int) (self.cacheSpaceSlider.value * self.totalSpace)];
}

- (IBAction)updateMinFreeSpaceSetting
{
	if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 0)
	{
		// Check if the user is trying to assing a higher min free space than is available space - 50MB
		if (self.cacheSpaceSlider.value * self.totalSpace > self.freeSpace - 52428800)
		{
			SavedSettings.si.minFreeSpace = self.freeSpace - 52428800;
			self.cacheSpaceSlider.value = ((float)SavedSettings.si.minFreeSpace / (float)self.totalSpace); // Leave 50MB space
		}
		else if (self.cacheSpaceSlider.value * self.totalSpace < 52428800)
		{
			SavedSettings.si.minFreeSpace = 52428800;
			self.cacheSpaceSlider.value = ((float)SavedSettings.si.minFreeSpace / (float)self.totalSpace); // Leave 50MB space
		}
		else 
		{
			SavedSettings.si.minFreeSpace = (unsigned long long int) (self.cacheSpaceSlider.value * (float)self.totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:SavedSettings.si.minFreeSpace];
	}
	else if (self.cachingTypeSegmentedControl.selectedSegmentIndex == 1)
	{
		
		// Check if the user is trying to assign a larger max cache size than there is available space - 50MB
		if (self.cacheSpaceSlider.value * self.totalSpace > self.freeSpace - 52428800)
		{
			SavedSettings.si.maxCacheSize = self.freeSpace - 52428800;
			self.cacheSpaceSlider.value = ((float)SavedSettings.si.maxCacheSize / (float)self.totalSpace); // Leave 50MB space
		}
		else if (self.cacheSpaceSlider.value * self.totalSpace < 52428800)
		{
			SavedSettings.si.maxCacheSize = 52428800;
			self.cacheSpaceSlider.value = ((float)SavedSettings.si.maxCacheSize / (float)self.totalSpace); // Leave 50MB space
		}
		else
		{
			SavedSettings.si.maxCacheSize = (unsigned long long int) (self.cacheSpaceSlider.value * self.totalSpace);
		}
		//cacheSpaceLabel2.text = [NSString formatFileSize:SavedSettings.si.maxCacheSize];
	}
	[self updateMinFreeSpaceLabel];
}

- (IBAction)revertMinFreeSpaceSlider
{
	self.cacheSpaceLabel2.text = [NSString formatFileSize:SavedSettings.si.minFreeSpace];
	self.cacheSpaceSlider.value = (float)SavedSettings.si.minFreeSpace / self.totalSpace;
}

- (IBAction)twitterButtonAction
{
//    ACAccountStore *account = [[ACAccountStore alloc] init];
//    ACAccountType *accountType = [account accountTypeWithAccountTypeIdentifier:ACAccountTypeIdentifierTwitter];
//    
//    if (SavedSettings.si.currentTwitterAccount)
//    {
//        SavedSettings.si.currentTwitterAccount = nil;
//        [self reloadTwitterUIElements];
//    }
//    else
//    {
//        [account requestAccessToAccountsWithType:accountType options:nil completion:^(BOOL granted, NSError *error)
//        {
//            if (granted == YES)
//            {
//                [EX2Dispatch runInMainThreadAsync:^
//                 {
//                     if ([[account accounts] count] == 1)
//                     {
//                         SavedSettings.si.currentTwitterAccount = [[[account accounts] firstObjectSafe] identifier];
//                         [self reloadTwitterUIElements];
//                     }
//                     else if ([[account accounts] count] > 1)
//                     {
//                         // more than one account, use Chooser
//                         IDTwitterAccountChooserViewController *chooser = [[IDTwitterAccountChooserViewController alloc] initWithRootViewController:self];
//                         [chooser setTwitterAccounts:[account accounts]];
//                         [chooser setCompletionHandler:^(ACAccount *account)
//                          {
//                              if (account)
//                              {
//                                  SavedSettings.si.currentTwitterAccount = [account identifier];
//                                  [self reloadTwitterUIElements];
//                              }
//                          }];
//                         [self.parentController.navigationController presentViewController:chooser animated:YES completion:nil];
//                     }
//                     else
//                     {
//                         [[[UIAlertView alloc] initWithTitle:nil message:NSLocalizedString(@"To use this feature, please add a Twitter account in the iOS Settings app.", @"No twitter accounts alert") delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil] show];
//                     }
//                 }];
//            }
//        }];
//    }
}

//	if (SocialSingleton.si.twitterEngine.isAuthorized)
//	{
//		[SocialSingleton.si destroyTwitterEngine];
//		[self reloadTwitterUIElements];
//	}
//	else
//	{
//		if (!SocialSingleton.si.twitterEngine)
//			[SocialSingleton.si createTwitterEngine];
//		
//		UIViewController *controller = [SA_OAuthTwitterController controllerToEnterCredentialsWithTwitterEngine:SocialSingleton.si.twitterEngine delegate:(id)SocialSingleton.si];
//		if (controller) 
//		{
//			if (IS_IPAD())
//				[AppDelegate.si.ipadRootViewController presentModalViewController:controller animated:YES];
//			else
//				[self.parentController presentModalViewController:controller animated:YES];
//		}
//	}
//}

- (void)dealloc 
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)textFieldDidBeginEditing:(UITextField *)textField
{
	UITableView *tableView = (UITableView *)self.view.superview;
	CGRect rect = CGRectMake(0, 500, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
	rect = UIInterfaceOrientationIsPortrait([[UIApplication sharedApplication] statusBarOrientation]) ? CGRectMake(0, 1600, 320, 5) : CGRectMake(0, 1455, 320, 5);
	[tableView scrollRectToVisible:rect animated:NO];
}

// This dismisses the keyboard when the "done" button is pressed
- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
	[self updateMinFreeSpaceSetting];
	[textField resignFirstResponder];
	return YES;
}

- (void)textFieldDidChange:(UITextField *)textField
{
	[self updateCacheSpaceSlider];
//DLog(@"file size: %llu   formatted: %@", [textField.text fileSizeFromFormat], [NSString formatFileSize:[textField.text fileSizeFromFormat]]);
}

// Fix for panel sliding while using sliders
- (IBAction)touchDown:(id)sender
{
    AppDelegate.si.sidePanelController.allowLeftSwipe = NO;
    AppDelegate.si.sidePanelController.allowRightSwipe = NO;
}
- (IBAction)touchUpInside:(id)sender
{
    AppDelegate.si.sidePanelController.allowLeftSwipe = YES;
    AppDelegate.si.sidePanelController.allowRightSwipe = YES;
}
- (IBAction)touchUpOutside:(id)sender
{
    AppDelegate.si.sidePanelController.allowLeftSwipe = YES;
    AppDelegate.si.sidePanelController.allowRightSwipe = YES;
}

@end
