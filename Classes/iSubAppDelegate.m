//
//  iSubAppDelegate.m
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "DatabaseControlsSingleton.h"
#import "MusicControlsSingleton.h"
#import "SocialControlsSingleton.h"
#import "MGSplitViewController.h"
#import "iPadMainMenu.h"
#import "InitialDetailViewController.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "ServerListViewController.h"
#import "RootViewController.h"
#import "Reachability.h"
#import "ASIHTTPRequest.h"
#import "URLCheckConnectionDelegate.h"
#import "APICheckConnectionDelegate.h"
#import "AudioStreamer.h"
#import "XMLParser.h"
#import "LyricsXMLParser.h"
#import "UpdateXMLParser.h"
#import "Album.h"
#import "Song.h"
#import <CoreFoundation/CoreFoundation.h>
#import <SystemConfiguration/SCNetworkReachability.h>
#include <netinet/in.h> 
#include <netdb.h>
#include <arpa/inet.h>
#import "CFNetworkRequests.h"
#import "NSString-hex.h"
#import "MKStoreManager.h"
#import "Server.h"
#import "UIDevice-Hardware.h"
#import "IntroViewController.h"
#import "CustomUIAlertView.h"
#import "HTTPServer.h"
#import "MyHTTPConnection.h"
#import "LocalhostAddresses.h"
#import "SFHFKeychainUtils.h"
#import "BWQuincyManager.h"
#import "BWHockeyManager.h"

@implementation iSubAppDelegate

@synthesize window;

@synthesize isIntroShowing;

// Main interface elements for iPhone
@synthesize background, currentTabBarController, mainTabBarController, offlineTabBarController;
@synthesize homeNavigationController, playerNavigationController, artistsNavigationController, rootViewController, allAlbumsNavigationController, allSongsNavigationController, playlistsNavigationController, bookmarksNavigationController, playingNavigationController, genresNavigationController, cacheNavigationController, chatNavigationController;

// Main interface elemements for iPad
@synthesize splitView, mainMenu, initialDetail;

// Network connectivity objects
@synthesize wifiReach, reachabilityStatus;

// User defaults
@synthesize defaultUrl, defaultUserName, defaultPassword, cachedIP, cachedIPHour;


// Settings
@synthesize settingsDictionary;


// Multitasking stuff
@synthesize isMultitaskingSupported, backgroundTask, isHighRez;


+ (iSubAppDelegate *)sharedInstance
{
	return (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation != UIInterfaceOrientationPortraitUpsideDown);
}

#pragma mark -
#pragma mark Application lifecycle
#pragma mark -

- (void)applicationDidFinishLaunching:(UIApplication *)application
{   
	//
	// Uncomment to redirect the console output to a log file
	//
	NSArray *paths = NSSearchPathForDirectoriesInDomains(NSDocumentDirectory, NSUserDomainMask, YES);
	NSString *documentsDirectory = [paths objectAtIndex:0];
	NSString *logPath = [documentsDirectory stringByAppendingPathComponent:@"console.log"];
	freopen([logPath cStringUsingEncoding:NSASCIIStringEncoding],"a+",stderr);
	//
	
	NSLog(@"1");

	// HockyApp Kits
#if defined (CONFIGURATION_AdHoc)
    [[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af"];
	[[BWQuincyManager sharedQuincyManager] setShowAlwaysButton:YES];
	[[BWHockeyManager sharedHockeyManager] setAppIdentifier:@"ada15ac4ffe3befbc66f0a00ef3d96af"];
	[[BWHockeyManager sharedHockeyManager] setAlwaysShowUpdateReminder:YES];
#endif
#if defined (CONFIGURATION_Release)
	if (IS_LITE())
		[[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"36cd77b2ee78707009f0a9eb9bbdbec7"];
	else
		[[BWQuincyManager sharedQuincyManager] setAppIdentifier:@"7c9cb46dad4165c9d3919390b651f6bb"];
	[[BWQuincyManager sharedQuincyManager] setShowAlwaysButton:YES];
#endif
	
	introController = nil;
	NSLog(@"2");
	//DLog(@"App finish launching called");
	viewObjects = [ViewObjectsSingleton sharedInstance];
	databaseControls = [DatabaseControlsSingleton sharedInstance];
	musicControls = [MusicControlsSingleton sharedInstance];
	socialControls = [SocialControlsSingleton sharedInstance];
	if (IS_LITE())
	{
		[MKStoreManager sharedManager];
		[MKStoreManager setDelegate:self];
		
#ifdef DEBUG
		// Reset features

		/*[SFHFKeychainUtils storeUsername:kFeaturePlaylistsId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
		[SFHFKeychainUtils storeUsername:kFeatureJukeboxId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
		[SFHFKeychainUtils storeUsername:kFeatureCacheId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];
		[SFHFKeychainUtils storeUsername:kFeatureAllId andPassword:@"NO" forServiceName:kServiceName updateExisting:YES error:nil];*/
		
		DLog(@"is kFeaturePlaylistsId enabled: %i", [MKStoreManager isFeaturePurchased:kFeaturePlaylistsId]);
		DLog(@"is kFeatureJukeboxId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureJukeboxId]);
		DLog(@"is kFeatureCacheId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureCacheId]);
		DLog(@"is kFeatureAllId enabled: %i", [MKStoreManager isFeaturePurchased:kFeatureAllId]);
#endif
	}

	NSLog(@"3");

	
	// Check if it's a retina display
	if ([[UIScreen mainScreen] respondsToSelector:@selector(scale)])
	{
		if ([[UIScreen mainScreen] scale] == 1.0)
		{
			isHighRez = NO;
		}
		else
		{
			isHighRez = YES;
		}
	}
	else 
	{
		isHighRez = NO;
	}
NSLog(@"4");
	// Setup network reachability notifications
	wifiReach = [[Reachability reachabilityForLocalWiFi] retain];
	[wifiReach startNotifier];
	[[NSNotificationCenter defaultCenter] addObserver: self selector: @selector(reachabilityChanged:) name: kReachabilityChangedNotification object: nil];
	
	// Limit the bandwidth over 3G to 500Kbps
	[ASIHTTPRequest throttleBandwidthForWWANUsingLimit:64000];
	//[NSTimer scheduledTimerWithTimeInterval:5 target:self selector:@selector(logAverageBandwidth) userInfo:nil repeats:YES];
	
	showIntro = NO;
	[self performSelectorInBackground:@selector(appInit) withObject:nil];
	
	// Initiallize the save state timer
	[NSTimer scheduledTimerWithTimeInterval:15.0 target:self selector:@selector(saveDefaults) userInfo:nil repeats:YES];
	NSLog(@"5");
	// Check battery state and register for notifications
	[UIDevice currentDevice].batteryMonitoringEnabled = YES;
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(batteryStateChanged:) name:@"UIDeviceBatteryStateDidChangeNotification" object:[UIDevice currentDevice]];
	[self batteryStateChanged:nil];	
	
	// Disable the screen idle timer if that setting is enabled
	if ([[settingsDictionary objectForKey:@"disableScreenSleepSetting"] isEqualToString:@"YES"])
		[UIApplication sharedApplication].idleTimerDisabled = YES;
	NSLog(@"6");
}

- (void)batteryStateChanged:(NSNotification *)notification
{
	UIDevice *device = [UIDevice currentDevice];
	if (device.batteryState == UIDeviceBatteryStateCharging || device.batteryState == UIDeviceBatteryStateFull) 
	{
			[UIApplication sharedApplication].idleTimerDisabled = YES;
    }
	else
	{
		if (![[settingsDictionary objectForKey:@"disableScreenSleepSetting"] isEqualToString:@"YES"])
			[UIApplication sharedApplication].idleTimerDisabled = NO;
	}
}

//
// If the available space has dropped below the max cache size since last app load, adjust it.
//
- (void) adjustCacheSize
{
	NSLog(@"adjustCacheSize:  [settingsDictionary objectForKey:@\"cachingTypeSetting\"] = %i", [[settingsDictionary objectForKey:@"cachingTypeSetting"] intValue]);
	// Only adjust if the user is using max cache size as option
	if ([[settingsDictionary objectForKey:@"cachingTypeSetting"] intValue] == 1)
	{
		unsigned long long int freeSpace = [[[[NSFileManager defaultManager] attributesOfFileSystemForPath:musicControls.audioFolderPath error:NULL] objectForKey:NSFileSystemFreeSize] unsignedLongLongValue];
		unsigned long long int maxCacheSize = [[settingsDictionary objectForKey:@"maxCacheSize"] unsignedLongLongValue];		
		
		NSLog(@"adjustCacheSize:  freeSpace = %llu  maxCacheSize = %llu", freeSpace, maxCacheSize);
		
		if (freeSpace < maxCacheSize)
		{
			unsigned long long int newMaxCacheSize = freeSpace - 26214400; // Set the max cache size to 25MB less than the free space
			[settingsDictionary setObject:[NSNumber numberWithUnsignedLongLong:newMaxCacheSize] forKey:@"maxCacheSize"];
			[[NSUserDefaults standardUserDefaults] setObject:settingsDictionary forKey:@"settingsDictionary"];
			[[NSUserDefaults standardUserDefaults] synchronize];
		}
	}
}

- (void)displayInfoUpdate:(NSNotification *) notification
{
	DLog(@"displayInfoUpdate:");
	
	if(notification)
	{
		[addresses release];
		addresses = [[notification object] copy];
		DLog(@"addresses: %@", addresses);
	}
	
	if(addresses == nil)
	{
		return;
	}
	
	NSString *info;
	UInt16 port = [httpServer port];
	
	NSString *localIP = nil;
	
	localIP = [addresses objectForKey:@"en0"];
	
	if (!localIP)
	{
		localIP = [addresses objectForKey:@"en1"];
	}
	
	if (!localIP)
		info = @"Wifi: No Connection!\n";
	else
		info = [NSString stringWithFormat:@"http://iphone.local:%d		http://%@:%d\n", port, localIP, port];
	
	NSString *wwwIP = [addresses objectForKey:@"www"];
	
	if (wwwIP)
		info = [info stringByAppendingFormat:@"Web: %@:%d\n", wwwIP, port];
	else
		info = [info stringByAppendingString:@"Web: Unable to determine external IP\n"];
	
	//displayInfo.text = info;
	DLog(@"info: %@", info);
}


- (void)startStopServer
{
	if (isHttpServerOn)
	{
		[httpServer stop];
	}
	else
	{
		// You may OPTIONALLY set a port for the server to run on.
		// 
		// If you don't set a port, the HTTP server will allow the OS to automatically pick an available port,
		// which avoids the potential problem of port conflicts. Allowing the OS server to automatically pick
		// an available port is probably the best way to do it if using Bonjour, since with Bonjour you can
		// automatically discover services, and the ports they are running on.
		//	[httpServer setPort:8080];
		
		NSError *error;
		if(![httpServer start:&error])
		{
			DLog(@"Error starting HTTP Server: %@", error);
		}
		
		[self displayInfoUpdate:nil];
	}
}

//
// Setup the basic defaults /* background thread */
//
- (void)appInit
{		
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	NSLog(@"7");
	// Create http server
	/*httpServer = [HTTPServer new];
	[httpServer setType:@"_http._tcp."];
	[httpServer setConnectionClass:[MyHTTPConnection class]];
	NSString *root = [NSSearchPathForDirectoriesInDomains(NSDocumentDirectory,NSUserDomainMask,YES) objectAtIndex:0];
	[httpServer setDocumentRoot:[NSURL fileURLWithPath:root]];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(displayInfoUpdate:) name:@"LocalhostAdressesResolved" object:nil];
	[LocalhostAddresses performSelectorInBackground:@selector(list) withObject:nil];*/
	
	// Set default settings
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if ([defaults objectForKey:@"settingsDictionary"])
	{
		self.settingsDictionary = [NSMutableDictionary dictionaryWithDictionary:[defaults objectForKey:@"settingsDictionary"]];
		
		// Add the scrobble and popup settings if not there - 3.0.1
		if ([settingsDictionary objectForKey:@"scrobblePercentSetting"] == nil)
		{
			NSNumber *percent = [NSNumber numberWithFloat:0.5];
			[settingsDictionary setObject:percent forKey:@"scrobblePercentSetting"];
			[settingsDictionary setObject:@"NO" forKey:@"enableScrobblingSetting"];
			[settingsDictionary setObject:@"NO" forKey:@"disablePopupsSetting"];
			[settingsDictionary setObject:@"NO" forKey:@"lockRotationSetting"];
		}
		
		// Add the new player overlay setting if not there - 3.0
		if ([settingsDictionary objectForKey:@"autoPlayerInfoSetting"] == nil)
		{
			DLog(@"Adding new player overlay setting");
			[settingsDictionary setObject:@"NO" forKey:@"autoPlayerInfoSetting"];
			[settingsDictionary setObject:@"NO" forKey:@"autoReloadArtistsSetting"];
			[settingsDictionary setObject:@"NO" forKey:@"enableSongsTabSetting"];
		}
		
		// Add the new settings if they aren't there - 2.2.3
		if ([settingsDictionary objectForKey:@"maxCacheSize"] == nil)
		{
			DLog(@"Adding new settings dictionary options");
			[settingsDictionary setObject:@"YES" forKey:@"enableSongCachingSetting"];
			[settingsDictionary setObject:@"YES" forKey:@"enableNextSongCacheSetting"];
			[settingsDictionary setObject:[NSNumber numberWithInt:0] forKey:@"cachingTypeSetting"];
			[settingsDictionary setObject:[NSNumber numberWithUnsignedLongLong:1073741824] forKey:@"maxCacheSize"];
		}
		
		// Add the new Wifi/3G bitrate settings if not there
		if ([settingsDictionary objectForKey:@"maxBitrateSetting"])
		{
			DLog(@"Adding new maxBitrateSettings");
			NSNumber *setting = [[[settingsDictionary objectForKey:@"maxBitrateSetting"] copy] autorelease];
			[settingsDictionary setObject:setting forKey:@"maxBitrateWifiSetting"];
			[settingsDictionary setObject:setting forKey:@"maxBitrate3GSetting"];
			[settingsDictionary removeObjectForKey:@"maxBitrateSetting"];
		}
		
		// Add the lyrics setting if it's not there
		if ([settingsDictionary objectForKey:@"lyricsEnabledSetting"] == nil)
		{
			DLog(@"Adding the enable lyrics setting");
			[settingsDictionary setObject:@"YES" forKey:@"lyricsEnabledSetting"];
		}
	}
	else
	{
		DLog(@"Creating new settings dictionary");
		self.settingsDictionary = [NSMutableDictionary dictionaryWithCapacity:8];
		[settingsDictionary setObject:@"NO" forKey:@"manualOfflineModeSetting"];
		[settingsDictionary setObject:[NSNumber numberWithInt:0] forKey:@"recoverSetting"];
		[settingsDictionary setObject:[NSNumber numberWithInt:7] forKey:@"maxBitrateWifiSetting"];
		[settingsDictionary setObject:[NSNumber numberWithInt:7] forKey:@"maxBitrate3GSetting"];
		[settingsDictionary setObject:@"YES" forKey:@"enableSongCachingSetting"];
		[settingsDictionary setObject:@"YES" forKey:@"enableNextSongCacheSetting"];
		[settingsDictionary setObject:[NSNumber numberWithInt:0] forKey:@"cachingTypeSetting"];
		[settingsDictionary setObject:[NSNumber numberWithUnsignedLongLong:1073741824] forKey:@"maxCacheSize"];
		[settingsDictionary setObject:[NSNumber numberWithUnsignedLongLong:268435456] forKey:@"minFreeSpace"];
		[settingsDictionary setObject:@"YES" forKey:@"autoDeleteCacheSetting"];
		[settingsDictionary setObject:[NSNumber numberWithInt:0] forKey:@"autoDeleteCacheTypeSetting"];
		[settingsDictionary setObject:[NSNumber numberWithInt:3] forKey:@"cacheSongCellColorSetting"];
		[settingsDictionary setObject:@"NO" forKey:@"twitterEnabledSetting"];
		[settingsDictionary setObject:@"YES" forKey:@"lyricsEnabledSetting"];
		[settingsDictionary setObject:@"NO" forKey:@"enableSongsTabSetting"];
	}
	
	// Save and sync the defaults
	[defaults setObject:settingsDictionary forKey:@"settingsDictionary"];
	[defaults synchronize];
	NSLog(@"8");
	// Handle In App Purchase Settings
	if (viewObjects.isCacheUnlocked == NO)
	{
		[settingsDictionary setObject:@"NO" forKey:@"enableSongCachingSetting"];
	}
	
	if ([[settingsDictionary objectForKey:@"manualOfflineModeSetting"] isEqualToString:@"YES"])
	{
		viewObjects.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Offline mode switch on, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	else if ([wifiReach currentReachabilityStatus] == NotReachable)
	{
		viewObjects.isOfflineMode = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"No network detected, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	else 
	{
		viewObjects.isOfflineMode = NO;
	}
	
	if ([[defaults objectForKey:@"isJukebox"] isEqualToString:@"YES"])
	{
		viewObjects.isJukebox = YES;
	}
	NSLog(@"9");
	
	self.isMultitaskingSupported = NO;
	UIDevice* device = [UIDevice currentDevice];
	if ([device respondsToSelector:@selector(isMultitaskingSupported)])
	{
		isMultitaskingSupported = device.multitaskingSupported;
	}
	
	
	if([defaults objectForKey:@"username"] != nil)
	{
		self.defaultUrl = [defaults objectForKey:@"url"];
		self.defaultUserName = [defaults objectForKey:@"username"];
		self.defaultPassword = [defaults objectForKey:@"password"];
		
		// Convert to the new Server object if necessary
		id serverList = [defaults objectForKey:@"servers"];
		if ([serverList isKindOfClass:[NSArray class]])
		{
			viewObjects.serverList = serverList;
			if ([viewObjects.serverList count] > 0)
			{
				if ([[viewObjects.serverList objectAtIndex:0] isKindOfClass:[NSArray class]])
				{
					NSMutableArray *newServerList = [[NSMutableArray alloc] init];
					
					for (NSArray *serverInfo in viewObjects.serverList)
					{
						Server *aServer = [[Server alloc] init];
						aServer.url = [NSString stringWithString:[serverInfo objectAtIndex:0]];
						aServer.username = [NSString stringWithString:[serverInfo objectAtIndex:1]];
						aServer.password = [NSString stringWithString:[serverInfo objectAtIndex:2]];
						aServer.type = SUBSONIC;
						
						[newServerList addObject:aServer];
						[aServer release];
					}
					
					viewObjects.serverList = [NSMutableArray arrayWithArray:newServerList];
					
					[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:viewObjects.serverList] forKey:@"servers"];
					[defaults synchronize];
					
					[newServerList release];
				}
			}
		}
		else
		{
			viewObjects.serverList = [NSKeyedUnarchiver unarchiveObjectWithData:serverList];
		}
		NSLog(@"9");
		//DLog(@"serverList: %@", viewObjects.serverList);
		
		[self appInit2];
		NSLog(@"10");
		[self adjustCacheSize];
		NSLog(@"11");
		[musicControls checkCache];
		NSLog(@"12");
		[self performSelectorOnMainThread:@selector(appInit3) withObject:nil waitUntilDone:NO];
		NSLog(@"13");
	}
	else
	{
		self.defaultUrl = DEFAULT_URL;
		self.defaultUserName = DEFAULT_USER_NAME;
		self.defaultPassword = DEFAULT_PASSWORD;
		
		if (viewObjects.isOfflineMode)
		{
			UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Welcome!" message:@"Looks like this is your first time using iSub or you haven't set up your Subsonic account info yet.\n\nYou'll need an internet connection to watch the intro video and use the included demo account." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
			[alert release];
		}
		else
		{
			showIntro = YES;
		}
		
		// Setup the HTTP Basic Auth credentials
		//NSURLCredential *credential = [NSURLCredential credentialWithUser:self.defaultUserName password:self.defaultPassword persistence:NSURLCredentialPersistenceForSession];
		//NSURLProtectionSpace *protectionSpace = [[NSURLProtectionSpace alloc] initWithHost:@"example.com" port:0 protocol:@"http" realm:nil authenticationMethod:NSURLAuthenticationMethodHTTPBasic];
		NSLog(@"14");
		
		[self appInit2];
		[self adjustCacheSize];
		[musicControls checkCache];
		[self performSelectorOnMainThread:@selector(appInit3) withObject:nil waitUntilDone:NO];
	}	
	
	[autoreleasePool release];
}

//
// Setup the server specific defaults and all of the databases /* background thread */
//
- (void)appInit2
{	
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	NSLog(@"15");
	// Check if the subsonic URL is valid by attempting to access the ping.view page, 
	// if it's not then display an alert and allow user to change settings if they want.
	// This is in case the user is, for instance, connected to a wifi network but does not 
	// have internet access or if the host url entered was wrong.
	BOOL isURLValid = YES;
	NSError *error;
	if (!viewObjects.isOfflineMode) 
	{
		//[NSThread sleepForTimeInterval:15];
		//DLog(@"%@", [NSString stringWithFormat:@"%@/rest/ping.view", defaultUrl]);
		isURLValid = [self isURLValid:[NSString stringWithFormat:@"%@/rest/ping.view", defaultUrl] error:&error];
		//DLog(@"isURLValid: %i", isURLValid);
	}
	NSLog(@"16");
	if(!isURLValid && !viewObjects.isOfflineMode)
	{
		//CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\nError code %i:\n%@", error.code, [ASIHTTPRequest errorCodeToEnglish:error.code]] delegate:self cancelButtonTitle:@"Retry" otherButtonTitles:@"Settings", nil];
		NSLog(@"17");
		viewObjects.isOfflineMode = YES;
		[databaseControls initDatabases];
		[viewObjects loadArtistList];
		NSLog(@"18");
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Server Unavailable" message:[NSString stringWithFormat:@"Either the Subsonic URL is incorrect, the Subsonic server is down, or you may be connected to Wifi but do not have access to the outside Internet.\n\n☆☆ Tap the gear in the top left and choose a server to return to online mode. ☆☆\n\nError code %i:\n%@", error.code, [ASIHTTPRequest errorCodeToEnglish:error.code]] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:@"Settings", nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	else
	{	
		/*if (!isOfflineMode)
		 {
		 // First check to see if the user used an IP address or a hostname. If they used a hostname,
		 // cache the IP of the host so that it doesn't need to be resolved for every call to the API
		 if ([[defaultUrl componentsSeparatedByString:@"."] count] == 1)
		 {
		 self.cachedIP = [[NSString alloc] initWithString:[self getIPAddressForHost:defaultUrl]];
		 self.cachedIPHour = [self getHour];
		 }
		 }*/
		NSLog(@"19");
		[databaseControls initDatabases];
		NSLog(@"20");
		[viewObjects loadArtistList];
		NSLog(@"21");
	}
	
	[autoreleasePool release];
}

//
// Handle resuming and load the main views /* main thread */
//
- (void) appInit3
{
	NSLog(@"22");
	// Recover current state if player was interrupted
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	if([[defaults objectForKey:@"recover"] isEqualToString:@"YES"])
	{
		//DLog(@"defaults isPlaying: %@", [[NSUserDefaults standardUserDefaults] objectForKey:@"isPlaying"]);
		if ([[defaults objectForKey:@"isPlaying"] isEqualToString:@"YES"])
		{
			if ([[settingsDictionary objectForKey:@"recoverSetting"] intValue] == 0)
			{
				//[musicControls resumeSong];
				[musicControls performSelectorInBackground:@selector(resumeSong) withObject:nil];
			}
			else if ([[settingsDictionary objectForKey:@"recoverSetting"] intValue] == 1)
			{
				[defaults setObject:@"NO" forKey:@"isPlaying"];
				[defaults synchronize];
				//[musicControls resumeSong];
				[musicControls performSelectorInBackground:@selector(resumeSong) withObject:nil];
			}
		}
		else
		{
			// Always resume when isPlaying == NO just to resume the song state, song doesn't play
			//[musicControls resumeSong];
			[musicControls performSelectorInBackground:@selector(resumeSong) withObject:nil];
		}
	}
	else 
	{
		//[self resetCurrentPlaylistDb];
		musicControls.bitRate = 192;
	}
	NSLog(@"23");
	// Start the queued downloads if Wifi is available
	musicControls.isQueueListDownloading = NO;
	if ([wifiReach currentReachabilityStatus] == ReachableViaWiFi)
	{
		//DLog(@"currentReachabilityStatus = Wifi - starting download of queue");
		reachabilityStatus = 2;
		[musicControls downloadNextQueuedSong];
	}
		NSLog(@"24");
	// Setup Twitter connection
	if (!viewObjects.isOfflineMode && [[NSUserDefaults standardUserDefaults] objectForKey: @"twitterAuthData"])
	{
		DLog(@"creating twitter engine");
		[socialControls createTwitterEngine];
		UIViewController *controller = [SA_OAuthTwitterController controllerToEnterCredentialsWithTwitterEngine:socialControls.twitterEngine delegate: socialControls];
		if (controller) 
			[mainTabBarController presentModalViewController:controller animated:YES];
	}
	NSLog(@"25");
	if ([settingsDictionary objectForKey:@"checkUpdatesSetting"] == nil)
	{
		// Ask to check for updates if haven't asked yet
		UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Update Alerts" message:@"Would you like iSub to notify you when app updates are available?\n\nYou can change this setting at any time from the settings menu." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		[alert show];
		[alert release];
	}
	else if ([[settingsDictionary objectForKey:@"checkUpdatesSetting"] isEqualToString:@"YES"])
	{
		[self performSelectorInBackground:@selector(checkForUpdate) withObject:nil];
	}
	NSLog(@"26");
	[self appInit4];
}

- (void) appInit4
{
	NSLog(@"27");
	introController = [[IntroViewController alloc] init];
	//intro.modalTransitionStyle = UIModalTransitionStyleCrossDissolve;
	if ([introController respondsToSelector:@selector(setModalPresentationStyle:)])
		introController.modalPresentationStyle = UIModalPresentationFormSheet;
	NSLog(@"28");
	if (IS_IPAD())
	{
		NSLog(@"29");
		// Setup the split view
		[window addSubview:splitView.view];
		splitView.showsMasterInPortrait = YES;
		splitView.splitPosition = 220;
		mainMenu = [[iPadMainMenu alloc] initWithNibName:@"iPadMainMenu" bundle:nil];
		
		splitView.masterViewController = mainMenu;
		
		if (showIntro)
		{
			[splitView presentModalViewController:introController animated:NO];
			isIntroShowing = YES;
		}
	}
	else
	{
		NSLog(@"30");
		// Setup the tabBarController
		mainTabBarController.moreNavigationController.navigationBar.barStyle = UIBarStyleBlack;
		
		//DLog(@"isOfflineMode: %i", viewObjects.isOfflineMode);
		if (viewObjects.isOfflineMode)
		{
			NSLog(@"31");
			//DLog(@"--------------- isOfflineMode");
			currentTabBarController = offlineTabBarController;
			[window addSubview:offlineTabBarController.view];
			NSLog(@"32");
		}
		else 
		{
			NSLog(@"33");
			// Recover the tab order and load the main tabBarController
			currentTabBarController = mainTabBarController;
			[viewObjects orderMainTabBarController];
			[window addSubview:mainTabBarController.view];
			NSLog(@"34");
		}
		
		if (showIntro)
		{
			NSLog(@"35");
			[currentTabBarController presentModalViewController:introController animated:NO];
			isIntroShowing = YES;
			NSLog(@"36");
		}
	}
	NSLog(@"37");
	if (viewObjects.isJukebox)
		window.backgroundColor = viewObjects.jukeboxColor;
	else 
		window.backgroundColor = viewObjects.windowColor;
NSLog(@"38");
	[window makeKeyAndVisible];	
	NSLog(@"39");
	/*[self startStopServer];*/
}

- (void)checkForUpdate
{
#if RELEASE
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:@"http://isubapp.com/update.xml"]];
	[request startSynchronous];
	if ([request error])
	{
		/*CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error checking for app updates." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];*/
		
		DLog(@"There was an error checking for app updates.");
	}
	else
	{
		DLog(@"%@", [[[NSString alloc] initWithData:[request responseData] encoding:NSUTF8StringEncoding] autorelease]);
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
		UpdateXMLParser *parser = [(UpdateXMLParser*) [UpdateXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		[xmlParser release];
		[parser release];
	}
	
	[autoreleasePool release];
#endif
}

- (void)applicationWillResignActive:(UIApplication*)application
{
	DLog(@"applicationWillResignActive called");
	
	//DLog(@"applicationWillResignActive finished");
}


- (void)applicationDidBecomeActive:(UIApplication*)application
{
	DLog(@"applicationDidBecomeActive called");
	
	//DLog(@"applicationDidBecomeActive finished");
}


- (void)applicationDidEnterBackground:(UIApplication *)application
{
	//DLog(@"applicationDidEnterBackground called");
	
	[self saveDefaults];
	
	[[NSUserDefaults standardUserDefaults] synchronize];
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(beginBackgroundTaskWithExpirationHandler:)])
    {
		backgroundTask = [[UIApplication sharedApplication] beginBackgroundTaskWithExpirationHandler:
						  ^{
							  // App is about to be put to sleep, stop the cache download queue
							  if (musicControls.isQueueListDownloading)
								  [musicControls stopDownloadQueue];
							  
							  // Make sure to end the background so we don't get killed by the OS
							  [application endBackgroundTask:backgroundTask];
							  backgroundTask = UIBackgroundTaskInvalid;
						  }];
		
		// Check the remaining background time and alert the user if necessary
		dispatch_queue_t queue = dispatch_queue_create("isub.backgroundqueue", 0);
		dispatch_async(queue, 
		^{
			isInBackground = YES;
			UIApplication *application = [UIApplication sharedApplication];
			while ([application backgroundTimeRemaining] > 1.0 && isInBackground) 
			{
				//DLog(@"backgroundTimeRemaining: %f", [application backgroundTimeRemaining]);
				
				// Sleep early is nothing is happening
				if ([application backgroundTimeRemaining] < 570.0 && !musicControls.isQueueListDownloading)
				{
					//DLog("Sleeping early, isQueueListDownloading: %i", musicControls.isQueueListDownloading);
					[application endBackgroundTask:backgroundTask];
					backgroundTask = UIBackgroundTaskInvalid;
					break;
				}
				
				// Warn at 2 minute mark if cache queue is downloading
				if ([application backgroundTimeRemaining] < 120.0 && musicControls.isQueueListDownloading)
				{
					UILocalNotification *localNotif = [[UILocalNotification alloc] init];
					if (localNotif) 
					{
						localNotif.alertBody = NSLocalizedString(@"Songs are still caching. Please return to iSub within 2 minutes, or it will be put to sleep and your song caching will be paused.", nil);
						localNotif.alertAction = NSLocalizedString(@"Open iSub", nil);
						[application presentLocalNotificationNow:localNotif];
						[localNotif release];
						break;
					}
				}
				
				// Sleep for a second to avoid a fast loop eating all cpu cycles
				sleep(1);
			}
		});
	}
}


- (void)applicationWillEnterForeground:(UIApplication *)application
{
	DLog(@"applicationWillEnterForeground called");
	
	if ([[UIApplication sharedApplication] respondsToSelector:@selector(endBackgroundTask:)])
    {
		isInBackground = NO;
		if (backgroundTask != UIBackgroundTaskInvalid)
		{
			[[UIApplication sharedApplication] endBackgroundTask:backgroundTask];
			backgroundTask = UIBackgroundTaskInvalid;
		}
	}
}


- (void)applicationWillTerminate:(UIApplication *)application
{
	DLog(@"applicationWillTerminate called");
	
	if (isMultitaskingSupported)
	{
		[[UIApplication sharedApplication] endReceivingRemoteControlEvents];
	}
	
	[self saveDefaults];
}

#pragma mark Helper Methods

- (void)saveDefaults
{
	NSAutoreleasePool *pool = [[NSAutoreleasePool alloc] init];
	
	//DLog(@"saveDefaults!!");
	
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];

	if(musicControls.isPlaying)
	{
		[defaults setObject:@"YES" forKey:@"isPlaying"];
	}
	else
	{
		[defaults setObject:@"NO" forKey:@"isPlaying"];
	}
	
	if (viewObjects.isJukebox)
	{
		[defaults setObject:@"NO" forKey:@"isPlaying"];
		[defaults setObject:@"YES" forKey:@"isJukebox"];
	}
	else
	{
		[defaults setObject:@"NO" forKey:@"isJukebox"];
	}
	
	if(musicControls.isShuffle)
	{
		[defaults setObject:@"YES" forKey:@"isShuffle"];
	}
	else 
	{
		[defaults setObject:@"NO" forKey:@"isShuffle"];
	}
	
	[defaults setObject:[NSString stringWithFormat:@"%i", musicControls.currentPlaylistPosition] forKey:@"currentPlaylistPosition"];
	[defaults setObject:[NSString stringWithFormat:@"%i", musicControls.repeatMode] forKey:@"repeatMode"];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:musicControls.currentSongObject] forKey:@"currentSongObject"];
	[defaults setObject:[NSKeyedArchiver archivedDataWithRootObject:musicControls.nextSongObject] forKey:@"nextSongObject"];
	[defaults setObject:[NSString stringWithFormat:@"%i", musicControls.streamer.bitRate] forKey:@"bitRate"];
	
	musicControls.streamerProgress = [musicControls.streamer progress];
	[defaults setObject:[NSString stringWithFormat:@"%f", (musicControls.seekTime + musicControls.streamerProgress)] forKey:@"seekTime"];
	[defaults setObject:@"YES" forKey:@"recover"];
	[defaults synchronize];	
	
	[pool release];
}



#pragma mark -
#pragma mark Other methods
#pragma mark -


#pragma mark Formatting Methods

- (NSString *) formatFileSize:(unsigned long long int)size
{
	if (size < 1024)
	{
		return [NSString stringWithFormat:@"%qu bytes", size];
	}
	else if (size >= 1024 && size < 1048576)
	{
		return [NSString stringWithFormat:@"%.02f KB", ((double)size / 1024)];
	}
	else if (size >= 1048576 && size < 1073741824)
	{
		return [NSString stringWithFormat:@"%.02f MB", ((double)size / 1024 / 1024)];
	}
	else if (size >= 1073741824)
	{
		return [NSString stringWithFormat:@"%.02f GB", ((double)size / 1024 / 1024 / 1024)];
	}
	
	return @"";
}

- (NSString *) formatTime:(float)seconds
{
	if (seconds <= 0)
		return @"0:00";
	
	int mins = (int) seconds / 60;
	int secs = (int) seconds % 60;
	if (secs < 10)
		return [NSString stringWithFormat:@"%i:0%i", mins, secs];
	else
		return [NSString stringWithFormat:@"%i:%i", mins, secs];
}

// Return the time since the date provided, formatted in English
- (NSString *) relativeTime:(NSDate *)date
{
	NSTimeInterval timeSinceDate = [[NSDate date] timeIntervalSinceDate:date];
	NSInteger time;
	
	if ([date isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0]])
	{
		return @"never";
	}
	if (timeSinceDate <= 60)
	{
		return @"just now";
	}
	else if (timeSinceDate > 60 && timeSinceDate <= 3600)
	{
		time = (int)(timeSinceDate / 60);
		
		if (time == 1)
			return @"1 minute ago";
		else
			return [NSString stringWithFormat:@"%i minutes ago", time];
	}
	else if (timeSinceDate > 3600 && timeSinceDate <= 86400)
	{
		time = (int)(timeSinceDate / 3600);
		
		if (time == 1)
			return @"1 hour ago";
		else
			return [NSString stringWithFormat:@"%i hours ago", time];
	}	
	else if (timeSinceDate > 86400 && timeSinceDate <= 604800)
	{
		time = (int)(timeSinceDate / 86400);
		
		if (time == 1)
			return @"1 day ago";
		else
			return [NSString stringWithFormat:@"%i days ago", time];
	}
	else if (timeSinceDate > 604800 && timeSinceDate <= 2629743.83)
	{
		time = (int)(timeSinceDate / 604800);
		
		if (time == 1)
			return @"1 week ago";
		else
			return [NSString stringWithFormat:@"%i weeks ago", time];
	}
	else if (timeSinceDate > 2629743.83)
	{
		time = (int)(timeSinceDate / 2629743.83);
		
		if (time == 1)
			return @"1 month ago";
		else
			return [NSString stringWithFormat:@"%i months ago", time];
	}
	
	return @"";
}

#pragma mark Helper Methods

- (void) logAverageBandwidth
{
	long long int usage = [ASIHTTPRequest averageBandwidthUsedPerSecond];
	usage = (usage * 8) / 1024; // convert to kbits
	//DLog(@"bandwidth usage: %qi kbps", usage);
}


- (void)enterOfflineMode
{
	/*isOfflineMode = YES;
	
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"No network detected, entering offline mode." delegate:self cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert show];
	[alert release];
	
	[self destroyStreamer];
	[self stopDownloadA];
	[self stopDownloadB];
	[mainTabBarController.view removeFromSuperview];
	[self closeAllDatabases];
	[self appInit2];
	self.currentTabBarController = offlineTabBarController;
	[self.window addSubview:[offlineTabBarController view]];*/

	if (viewObjects.isNoNetworkAlertShowing == NO)
	{
		viewObjects.isNoNetworkAlertShowing = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"No network detected, would you like to enter offline mode? Any currently playing music will stop.\n\nIf this is just temporary connection loss, select No." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		[alert show];
		[alert release];
	}
}


- (void)enterOnlineMode
{
	if (!viewObjects.isOnlineModeAlertShowing)
	{
		viewObjects.isOnlineModeAlertShowing = YES;
		
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Notice" message:@"Network detected, would you like to enter online mode? Any currently playing music will stop." delegate:self cancelButtonTitle:@"No" otherButtonTitles:@"Yes", nil];
		[alert show];
		[alert release];
	}
}


- (void)enterOfflineModeForce
{
	if (viewObjects.isOfflineMode)
		return;
	
	viewObjects.isOfflineMode = YES;
		
	[musicControls destroyStreamer];
	[musicControls stopDownloadA];
	[musicControls stopDownloadB];
	[mainTabBarController.view removeFromSuperview];
	[databaseControls closeAllDatabases];
	[self appInit2];
	currentTabBarController = offlineTabBarController;
	[window addSubview:[offlineTabBarController view]];
}

- (void)enterOnlineModeForce
{
	if ([wifiReach currentReachabilityStatus] == NotReachable)
		return;
		
	viewObjects.isOfflineMode = NO;
	
	[musicControls destroyStreamer];
	[offlineTabBarController.view removeFromSuperview];
	[databaseControls closeAllDatabases];
	[self appInit2];
	[viewObjects orderMainTabBarController];
	[window addSubview:[mainTabBarController view]];
}


- (void)reachabilityChanged: (NSNotification *)note
{
	if ([[settingsDictionary objectForKey:@"manualOfflineModeSetting"] isEqualToString:@"YES"])
		return;
	
	Reachability* curReach = [note object];
	NSParameterAssert([curReach isKindOfClass: [Reachability class]]);
	
	if ([curReach currentReachabilityStatus] == NotReachable)
	{
		DLog(@"Reachability Changed: NotReachable");
		reachabilityStatus = 0;
		//[self stopDownloadQueue];
		
		//Change over to offline mode
		if (!viewObjects.isOfflineMode)
		{
			[self enterOfflineMode];
		}
	}
	else if ([curReach currentReachabilityStatus] == ReachableViaWiFi || IS_3G_UNRESTRICTED)
	{
		DLog(@"Reachability Changed: ReachableViaWiFi");
		reachabilityStatus = 2;
		
		if (viewObjects.isOfflineMode)
		{
			[self enterOnlineMode];
		}
		else
		{
			DLog(@"musicControls.isQueueListDownloading: %i", musicControls.isQueueListDownloading);
			if (!musicControls.isQueueListDownloading) {
				DLog(@"Calling [musicControls downloadNextQueuedSong]");
				[musicControls downloadNextQueuedSong];
			}
		}
	}
	else if ([curReach currentReachabilityStatus] == ReachableViaWWAN)
	{
		DLog(@"Reachability Changed: ReachableViaWWAN");
		reachabilityStatus = 1;
		
		if (viewObjects.isOfflineMode)
		{
			[self enterOnlineMode];
		}
		else 
		{
			[musicControls stopDownloadQueue];
		}
	}
}

- (BOOL)isWifi
{
	if ([wifiReach currentReachabilityStatus] == ReachableViaWiFi || IS_3G_UNRESTRICTED)
		return YES;
	else
		return NO;
}

- (void)showSettings
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	
	if (currentTabBarController.selectedIndex == 4)
	{
		[currentTabBarController.moreNavigationController popToViewController:[currentTabBarController.moreNavigationController.viewControllers objectAtIndex:1] animated:YES];
		[currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
	}
	else if (currentTabBarController.selectedIndex == NSNotFound)
	{
		[currentTabBarController.moreNavigationController popToRootViewControllerAnimated:YES];
		[currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
	}
	else
	{
		[(UINavigationController*)currentTabBarController.selectedViewController popToRootViewControllerAnimated:YES];
		[(UINavigationController*)currentTabBarController.selectedViewController pushViewController:serverListViewController animated:YES];
	}
	
	[serverListViewController release];
}

- (void)alertView:(UIAlertView *)alertView clickedButtonAtIndex:(NSInteger)buttonIndex
{
	if ([alertView.title isEqualToString:@"Subsonic Error"])
	{
		if(buttonIndex == 1)
		{
			if (IS_IPAD())
			{
				[mainMenu showSettings];
			}
			else
			{
				ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
				
				if (currentTabBarController.selectedIndex == 4)
				{
					[currentTabBarController.moreNavigationController pushViewController:serverListViewController animated:YES];
				}
				else
				{
					[(UINavigationController*)currentTabBarController.selectedViewController pushViewController:serverListViewController animated:YES];
				}
				
				[serverListViewController release];
			}
		}
	}
	else if ([alertView.title isEqualToString:@"Error"])
	{
		if (isIntroShowing)
		{
			[introController dismissModalViewControllerAnimated:NO];
		}
		
		if (buttonIndex == 0)
		{
			[self appInit2];
		}
		else if (buttonIndex == 1)
		{
			if (IS_IPAD())
			{
				[mainMenu showSettings];
			}
			else
			{
				[self showSettings];
			}
		}
	}
	else if ([alertView.title isEqualToString:@"Server Unavailable"])
	{
		if (buttonIndex == 1)
		{
			[self showSettings];
		}
	}
	else if ([alertView.title isEqualToString:@"Notice"])
	{
		// Offline mode handling
		
		viewObjects.isOnlineModeAlertShowing = NO;
		viewObjects.isNoNetworkAlertShowing = NO;
		
		if (buttonIndex == 1)
		{
			if (viewObjects.isOfflineMode)
			{
				viewObjects.isOfflineMode = NO;
				
				[musicControls destroyStreamer];
				[offlineTabBarController.view removeFromSuperview];
				[databaseControls closeAllDatabases];
				[self appInit2];
				[viewObjects orderMainTabBarController];
				[window addSubview:[mainTabBarController view]];
			}
			else
			{
				viewObjects.isOfflineMode = YES;
				viewObjects.isJukebox = NO;
				
				[musicControls destroyStreamer];
				[musicControls stopDownloadA];
				[musicControls stopDownloadB];
				[musicControls stopDownloadQueue];
				[mainTabBarController.view removeFromSuperview];
				[databaseControls closeAllDatabases];
				[self appInit2];
				currentTabBarController = offlineTabBarController;
				[window addSubview:[offlineTabBarController view]];
			}
		}
	}
	else if ([alertView.title isEqualToString:@"Resume?"])
	{
		if (buttonIndex == 0)
		{
			musicControls.bitRate = 192;
		}
		if (buttonIndex == 1)
		{
			//[musicControls resumeSong];
			[musicControls performSelectorInBackground:@selector(resumeSong) withObject:nil];
			
			// Reload the tab to display the Now Playing button - NOTE: DOESN'T WORK WHEN MORE TAB IS SELECTED
			if (currentTabBarController.selectedIndex == 4)
			{
				[[currentTabBarController.moreNavigationController topViewController] viewWillAppear:NO];				
			}
			else if (currentTabBarController.selectedIndex == NSNotFound)
			{
				[[currentTabBarController.moreNavigationController topViewController] viewWillAppear:NO];
			}
			else
			{
				[[(UINavigationController*)currentTabBarController.selectedViewController topViewController] viewWillAppear:NO];				
			}
		}
	}
	else if ([alertView.title isEqualToString:@"Update Alerts"])
	{
		if (buttonIndex == 0)
		{
			[settingsDictionary setObject:@"NO" forKey:@"checkUpdatesSetting"];
		}
		else if (buttonIndex == 1)
		{
			[settingsDictionary setObject:@"YES" forKey:@"checkUpdatesSetting"];
		}
		
		[[NSUserDefaults standardUserDefaults] setObject:settingsDictionary forKey:@"settingsDictionary"];
		[[NSUserDefaults standardUserDefaults] synchronize];
	}
}


- (BOOL)isURLValid:(NSString *)url error:(NSError **)error
{	
	//DLog(@"isURLValid url: %@", url);
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:[NSURL URLWithString:url]];
	[request setTimeOutSeconds:15];
	[request startSynchronous];
	NSError *conError = [request error];
	
	if(conError.code)
	{
		*error = conError;
		return NO;
	}
	else
	{
		return YES;
	}
}


/*- (BOOL)wifiReachability
{
	switch ([wifiReach currentReachabilityStatus])
	{
		case NotReachable:
		{
			return NO;
		}
		case ReachableViaWWAN:
		{
			return NO;
		}
		case ReachableViaWiFi:
		{
			return YES;
		}
	}
	
	return NO;
}*/


/*- (BOOL) connectedToNetwork
{
	// Create zero addy
	struct sockaddr_in zeroAddress;
	bzero(&zeroAddress, sizeof(zeroAddress));
	zeroAddress.sin_len = sizeof(zeroAddress);
	zeroAddress.sin_family = AF_INET;
	
	// Recover reachability flags
	SCNetworkReachabilityRef defaultRouteReachability = SCNetworkReachabilityCreateWithAddress(NULL, (struct sockaddr *)&zeroAddress);
	SCNetworkReachabilityFlags flags;
	
	BOOL didRetrieveFlags = SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags);
	CFRelease(defaultRouteReachability);
	
	if (!didRetrieveFlags) {
		printf("Error. Could not recover network reachability flags\n"); return 0;
	}
	
	BOOL isReachable = flags & kSCNetworkFlagsReachable;
	BOOL needsConnection = flags & kSCNetworkFlagsConnectionRequired;
	return (isReachable && !needsConnection) ? YES : NO;
}*/


- (NSString *) getIPAddressForHost: (NSString *) theHost 
{
	/*NSArray *subStrings = [theHost componentsSeparatedByString:@"://"];
	theHost = [subStrings objectAtIndex:1];
	subStrings = [theHost componentsSeparatedByString:@":"];
	theHost = [subStrings objectAtIndex:0];
	
	struct hostent *host = gethostbyname([theHost UTF8String]);
	if (host == NULL) 
	{
		herror("resolv");
		return NULL;
	}
	
	struct in_addr **list = (struct in_addr **)host->h_addr_list;
	//NSString *addressString = [NSString stringWithCString:inet_ntoa(*list[0])];
	NSString *addressString = [NSString stringWithCString:inet_ntoa(*list[0]) encoding:NSUTF8StringEncoding];
	return addressString;*/
	
	URLCheckConnectionDelegate *connDelegate = [[URLCheckConnectionDelegate alloc] init];
	connDelegate.connectionFinished = NO;
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:theHost] cachePolicy:NSURLRequestReturnCacheDataElseLoad timeoutInterval:30.0];
	[[NSURLConnection alloc] initWithRequest:request delegate:connDelegate];
	
	// Wait for the redirects to finish
	while (connDelegate.connectionFinished == NO)
	{
		DLog(@"Waiting for connection to finish");
	}
	
	//
	// Finish writing logic
	//
	
	return @"";
}


- (NSInteger) getHour
{
	// Get the time
	NSCalendar *calendar= [[NSCalendar alloc] initWithCalendarIdentifier:NSGregorianCalendar];
	NSCalendarUnit unitFlags = NSYearCalendarUnit | NSMonthCalendarUnit | NSDayCalendarUnit | NSHourCalendarUnit | NSMinuteCalendarUnit | NSSecondCalendarUnit;
	NSDate *date = [NSDate date];
	NSDateComponents *dateComponents = [calendar components:unitFlags fromDate:date];

	// Turn the date into Integers
	//NSInteger year = [dateComponents year];
	//NSInteger month = [dateComponents month];
	//NSInteger day = [dateComponents day];
	//NSInteger hour = [dateComponents hour];
	//NSInteger min = [dateComponents minute];
	//NSInteger sec = [dateComponents second];
	
	[calendar release];
	return [dateComponents hour];
}

- (void) checkAPIVersion
{
	// Only perform check in online mode
	if (!viewObjects.isOfflineMode)
	{
		APICheckConnectionDelegate *conDelegate = [[APICheckConnectionDelegate alloc] init];
		
		NSString *urlString = [self getBaseUrl:@"ping.view"];
		NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] 
												 cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData 
											 timeoutInterval:kLoadingTimeout];
		NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:conDelegate];
		if (!connection)
		{
			// Inform the user that the connection failed.
			CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Version Check Error" message:@"There was an error checking the server version.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
			[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
			[alert release];
		}
		
		[conDelegate release];
	}
}

#pragma mark -
#pragma mark Music Streamer
#pragma mark -



- (NSString *)getBaseUrl:(NSString *)action
{	
	//NSString *urlString = [[[NSString alloc] init] autorelease];
	// If the user used a hostname, implement the IP address caching and create the urlstring
	/*if ([[defaultUrl componentsSeparatedByString:@"."] count] == 1)
	{
		// Check to see if it's been an hour since the last IP check. If it has, update the cached IP.
		if ([self getHour] > cachedIPHour)
		{
			cachedIP = [[NSString alloc] initWithString:[self getIPAddressForHost:defaultUrl]];
			cachedIPHour = [self getHour];
		}
	
		// Grab the http (or https for the future) and the port (if there is one)
		NSArray *subStrings = [defaultUrl componentsSeparatedByString:@":"];
		if ([subStrings count] == 2)
			urlString = [NSString stringWithFormat:@"%@://%@", [subStrings objectAtIndex:0], cachedIP];
		else if ([subStrings count] == 3)
			urlString = [NSString stringWithFormat:@"%@://%@:%@", [subStrings objectAtIndex:0], cachedIP, [subStrings objectAtIndex:2]];
	}
	else 
	{
		// If the user used an IP address, just use the defaultUrl as is.
		urlString = defaultUrl;
	}*/
	NSString *urlString = [[defaultUrl copy] autorelease];
	
	NSString *encodedUserName = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)defaultUserName, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	NSString *encodedPassword = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)defaultPassword, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );

	//DLog(@"username: %@    password: %@", encodedUserName, encodedPassword);
	
	// Return the base URL
	if ([action isEqualToString:@"getIndexes.view"] || [action isEqualToString:@"search.view"] || [action isEqualToString:@"search2.view"] || [action isEqualToString:@"getNowPlaying.view"] || [action isEqualToString:@"getPlaylists.view"] || [action isEqualToString:@"getMusicFolders.view"] || [action isEqualToString:@"createPlaylist.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.1.0&c=iSub", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"stream.view"] && [[settingsDictionary objectForKey:@"maxBitrateSetting"] intValue] != 7)
	{
		return [NSString stringWithFormat:@"%@/rest/stream.view?maxBitRate=%i&u=%@&p=%@&v=1.2.0&c=iSub&id=", urlString, [musicControls maxBitrateSetting], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"addChatMessage.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/addChatMessage.view?&u=%@&p=%@&v=1.2.0&c=iSub&message=", urlString, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getLyrics.view"])
	{
		NSString *encodedArtist = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicControls.currentSongObject.artist, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		NSString *encodedTitle = (NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef)musicControls.currentSongObject.title, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
		
		return [NSString stringWithFormat:@"%@/rest/getLyrics.view?artist=%@&title=%@&u=%@&p=%@&v=1.2.0&c=iSub", urlString, [encodedArtist autorelease], [encodedTitle autorelease], [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else if ([action isEqualToString:@"getRandomSongs.view"] || [action isEqualToString:@"getAlbumList.view"] || [action isEqualToString:@"jukeboxControl.view"])
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.2.0&c=iSub", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
	else
	{
		return [NSString stringWithFormat:@"%@/rest/%@?u=%@&p=%@&v=1.1.0&c=iSub&id=", urlString, action, [encodedUserName autorelease], [encodedPassword autorelease]];
	}
}


#pragma mark -
#pragma mark Store Manager delegate
#pragma mark -

/*- (void)productFetchComplete
 {
 CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Store" message:@"Product fetch complete" delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
 [alert show];
 [alert release];
 }*/

- (void)productPurchased:(NSString *)productId
{
	NSString *message = nil;
	if ([productId isEqualToString:kFeatureAllId])
		message = @"You may now use all of the iSub features.";
	else if ([productId isEqualToString:kFeaturePlaylistsId])
		message = @"You may now use the playlist feature.";
	else if ([productId isEqualToString:kFeatureCacheId])
		message = @"You may now use the song caching feature.";
	else if ([productId isEqualToString:kFeatureJukeboxId])
		message = @"You may now use the jukebox feature.";
	else
		message = @"";
	
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Purchase Successful!" message:message delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
	[alert release];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"storePurchaseComplete" object:nil];
}

- (void)transactionCanceled
{
	UIAlertView *alert = [[UIAlertView alloc] initWithTitle:@"Store" message:@"Transaction canceled. Try again." delegate:nil cancelButtonTitle:@"Ok" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:YES];
	[alert release];
}


#pragma mark -
#pragma mark Memory management
#pragma mark -

//
// Not necessary in the application delegate, all memory is automatically reclaimed by OS on closing
//
- (void)dealloc 
{	
	//[wwanReach release];
	[wifiReach release];
	
	[defaultUrl release];
	[defaultUserName release];
	[defaultPassword release];
	[cachedIP release];
	
	[super dealloc];
}


@end

