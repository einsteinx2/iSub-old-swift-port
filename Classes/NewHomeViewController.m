//
//  NewHomeViewController.m
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "NewHomeViewController.h"
#import "iSub-Swift.h"
#import "ServerListViewController.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "QuickAlbumsViewController.h"
#import "SearchSongsViewController.h"
#import "ShuffleFolderPickerViewController.h"
#import "FolderPickerDialog.h"
#import "SearchAllViewController.h"
#import <QuartzCore/QuartzCore.h>
#import "UIViewController+PushViewControllerCustom.h"
#import "iPadRootViewController.h"
#import "MenuViewController.h"
#import "SearchXMLParser.h"
#import "ISMSPlayerViewController.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSMutableURLRequest+PMS.h"

@interface NewHomeViewController()
{
    UIView *_searchOverlay;
    UIButton *_dismissButton;
    BOOL _isSearch;
    UIButton *_coverArtBorder;
    AsynchronousImageView *_coverArtView;
    UILabel *_artistLabel;
    UILabel *_albumLabel;
    UILabel *_songLabel;
    NSURLConnection *_connection;
    NSMutableData *_receivedData;
}
@property (nonatomic, strong) IBOutlet UISearchBar *searchBar;
@property (nonatomic, strong) IBOutlet UISegmentedControl *searchSegment;
@property (nonatomic, strong) IBOutlet UIView *searchSegmentBackground;
@property (nonatomic, strong) IBOutlet UIButton *jukeboxButton;
@property (nonatomic, strong) IBOutlet UILabel *quickLabel;
@property (nonatomic, strong) IBOutlet UILabel *shuffleLabel;
@property (nonatomic, strong) IBOutlet UILabel *jukeboxLabel;
@property (nonatomic, strong) IBOutlet UILabel *settingsLabel;
@property (nonatomic, strong) IBOutlet UILabel *chatLabel;
@property (nonatomic, strong) IBOutlet UILabel *playerLabel;
@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *topRow;
@property (nonatomic, strong) IBOutletCollection(UILabel) NSArray *topRowLabels;
@property (nonatomic, strong) IBOutletCollection(UIButton) NSArray *bottomRow;
@property (nonatomic, strong) IBOutletCollection(UILabel) NSArray *bottomRowLabels;
@end

@implementation NewHomeViewController

#pragma mark - Rotation -

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[super willRotateToInterfaceOrientation:toInterfaceOrientation duration:duration];
	
	BOOL rotationDisabled = settingsS.isRotationLockEnabled;
	
	if (UIInterfaceOrientationIsPortrait(toInterfaceOrientation))
	{
		if (!IS_IPAD())
		{
			// Animate the segmented control off screen
            [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                _quickLabel.alpha = 1.0;
                _shuffleLabel.alpha = 1.0;
                _jukeboxLabel.alpha = 1.0;
                _settingsLabel.alpha = 1.0;
                _chatLabel.alpha = 1.0;
                _playerLabel.alpha = 1.0;
                
                _coverArtBorder.alpha = 1.0;
                _coverArtView.alpha = 1.0;
                _artistLabel.alpha = 1.0;
                _albumLabel.alpha = 1.0;
                _songLabel.alpha = 1.0;
            } completion:nil];
            
            if (IS_TALL_SCREEN())
            {
                [UIView animateWithDuration:duration animations:^{
                     for (UIView *aView in _topRow)
                     {
                         aView.y = 75.;
                     }
                     
                     for (UIView *aView in _topRowLabels)
                     {
                         aView.y = 145.;
                     }
                     
                     _coverArtBorder.y = 217.;
                     
                     for (UIView *aView in _bottomRow)
                     {
                         aView.y = 115;
                     }
                     
                     for (UIView *aView in _bottomRowLabels)
                     {
                         aView.y = 160;
                     }
                 }];
            }
		}
	}
	else if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation) && !rotationDisabled)
	{
		if (!IS_IPAD())
		{
            if (IS_TALL_SCREEN())
            {
                for (UIView *aView in _topRow)
                {
                    aView.y -= 30;
                }
                
                _coverArtBorder.y -= 40;
                
                for (UIView *aView in _bottomRow)
                {
                    aView.y += 40;
                }
            }
            
			// Animate the segmented control off screen
            [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
                _quickLabel.alpha = 0.0;
                _shuffleLabel.alpha = 0.0;
                _jukeboxLabel.alpha = 0.0;
                _settingsLabel.alpha = 0.0;
                _chatLabel.alpha = 0.0;
                _playerLabel.alpha = 0.0;
                
                _coverArtBorder.alpha = 0.0;
                _coverArtView.alpha = 0.0;
                _artistLabel.alpha = 0.0;
                _albumLabel.alpha = 0.0;
                _songLabel.alpha = 0.0;
            } completion:nil];
		}
	}
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
    // Since the values in viewWillRotate would have to be rounded, we need to fix them here
    if (IS_TALL_SCREEN())
    {
        if (UIInterfaceOrientationIsLandscape(fromInterfaceOrientation))
        {
            for (UIView *aView in _topRow)
            {
                aView.y = 75.;
            }
            
            for (UIView *aView in _topRowLabels)
            {
                aView.y = 145.;
            }
            
            _coverArtBorder.y = 217.;
            
            for (UIView *aView in _bottomRow)
            {
                aView.y = 313.;
            }
            
            for (UIView *aView in _bottomRowLabels)
            {
                aView.y = 381;
            }
        }
        else
        {
            for (UIView *aView in _topRow)
            {
                aView.y = 45.;
            }
            
            for (UIView *aView in _topRowLabels)
            {
                aView.y = 115.;
            }
            
            _coverArtBorder.y = 177.;
            
            for (UIView *aView in _bottomRow)
            {
                aView.y = 127.;
            }
            
            for (UIView *aView in _bottomRowLabels)
            {
                aView.y = 159.;
            }
        }
    }    
}

#pragma mark - Lifecycle -

- (void)viewDidLoad
{
	[super viewDidLoad];
    
    _searchSegment.tintColor = ISMSHeaderColor;
    _searchSegmentBackground.backgroundColor = [UIColor colorWithWhite:.3 alpha:1];
    
	_searchSegment.selectedSegmentIndex = 3;
	
	self.title = @"Home";
    
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_jukeboxDisabled:) name:ISMSNotification_JukeboxDisabled object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_songPlaybackStarted:) name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_serverSwitched:) name:ISMSNotification_ServerSwitched object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_performServerShuffle:) name:@"performServerShuffle" object:nil];
    [[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(_applicationDidBecomeActive:) name:UIApplicationDidBecomeActiveNotification object:nil];

	if (!IS_IPAD())
	{
		_coverArtBorder = [UIButton buttonWithType:UIButtonTypeCustom];
		_coverArtBorder.frame = CGRectMake(15, 177, 290, 60);
		_coverArtBorder.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
		_coverArtBorder.layer.borderWidth = 2.0f;
		[_coverArtBorder addTarget:self action:@selector(showPlayer) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:_coverArtBorder];
		
		_coverArtView = [[AsynchronousImageView alloc] init];
		_coverArtView.isLarge = NO;
		_coverArtView.frame = CGRectMake(0, 0, 60, 60);
		_coverArtView.layer.borderColor = [UIColor colorWithWhite:0.7 alpha:1.0].CGColor;
		_coverArtView.layer.borderWidth = 2.0f;
		
		[_coverArtBorder addSubview:_coverArtView];
		
		_artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 3, 220, 20)];
		_artistLabel.backgroundColor = [UIColor clearColor];
		_artistLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		_artistLabel.font = ISMSBoldFont(17);
		_artistLabel.minimumScaleFactor = 12.0 / _artistLabel.font.pointSize;
		_artistLabel.adjustsFontSizeToFitWidth = YES;
		_artistLabel.textAlignment = NSTextAlignmentCenter;
		_artistLabel.shadowOffset = CGSizeMake(0, 2);
		_artistLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		[_coverArtBorder addSubview:_artistLabel];
		
		_albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 20, 220, 20)];
		_albumLabel.backgroundColor = [UIColor clearColor];
		_albumLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		_albumLabel.font = ISMSRegularFont(17);
		_albumLabel.minimumScaleFactor = 12.0 / _albumLabel.font.pointSize;
		_albumLabel.adjustsFontSizeToFitWidth = YES;
		_albumLabel.textAlignment = NSTextAlignmentCenter;
		_albumLabel.shadowOffset = CGSizeMake(0, 2);
		_albumLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		[_coverArtBorder addSubview:_albumLabel];
		
		_songLabel = [[UILabel alloc] initWithFrame:CGRectMake(65, 37, 220, 20)];
		_songLabel.backgroundColor = [UIColor clearColor];
		_songLabel.textColor = [UIColor colorWithWhite:0.7 alpha:1.0];
		_songLabel.font = ISMSBoldFont(17);
		_songLabel.minimumScaleFactor = 12.0 / _songLabel.font.pointSize;
		_songLabel.adjustsFontSizeToFitWidth = YES;
		_songLabel.textAlignment = NSTextAlignmentCenter;
		_songLabel.shadowOffset = CGSizeMake(0, 2);
		_songLabel.shadowColor = [UIColor colorWithWhite:0 alpha:0.25];
		[_coverArtBorder addSubview:_songLabel];
        		
		[self _initSongInfo];
	}
}

- (void)viewWillAppear:(BOOL)animated
{
	[super viewWillAppear:animated];
    
	if (UIInterfaceOrientationIsPortrait(self.interfaceOrientation))
	{
		if (!IS_IPAD())
		{
			_quickLabel.alpha = 1.0;
			_shuffleLabel.alpha = 1.0;
			_jukeboxLabel.alpha = 1.0;
			_settingsLabel.alpha = 1.0;
			_chatLabel.alpha = 1.0;
			_playerLabel.alpha = 1.0;
			
			_coverArtBorder.alpha = 1.0;
			_coverArtView.alpha = 1.0;
			_artistLabel.alpha = 1.0;
			_albumLabel.alpha = 1.0;
			_songLabel.alpha = 1.0;
            
            if (IS_TALL_SCREEN())
            {
                // Make sure everything's in the right place
                [self didRotateFromInterfaceOrientation:UIInterfaceOrientationLandscapeLeft];
            }
		}
	}
	else if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
	{
		if (!IS_IPAD())
		{
			_quickLabel.alpha = 0.0;
			_shuffleLabel.alpha = 0.0;
			_jukeboxLabel.alpha = 0.0;
			_settingsLabel.alpha = 0.0;
			_chatLabel.alpha = 0.0;
			_playerLabel.alpha = 0.0;
			
			_coverArtBorder.alpha = 0.0;
			_coverArtView.alpha = 0.0;
			_artistLabel.alpha = 0.0;
			_albumLabel.alpha = 0.0;
			_songLabel.alpha = 0.0;
            
            if (IS_TALL_SCREEN())
            {
                // Make sure everything's in the right place
                [self didRotateFromInterfaceOrientation:UIInterfaceOrientationPortrait];
            }
		}
	}
    
    [self _addURLRefBackButton];
	
    self.navigationItem.rightBarButtonItem = nil;
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing"]
                                                                                  style:UIBarButtonItemStyleBordered
                                                                                 target:self
                                                                                 action:@selector(a_nowPlaying:)];
	}
    
    [self _updateJukeboxIcon];
	
	_searchSegment.alpha = 0.0;
	_searchSegment.enabled = NO;
	_searchSegmentBackground.alpha = 0.0;
	
	[Flurry logEvent:@"HomeTab"];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

#pragma mark - Notifications -

- (void)_jukeboxDisabled:(NSNotification *)notification
{
    [self _updateJukeboxIcon];
    
    [self _initSongInfo];
}

- (void)_songPlaybackStarted:(NSNotification *)notification
{
    [self _initSongInfo];
}

- (void)_serverSwitched:(NSNotification *)notification
{
    [self _initSongInfo];
}

- (void)_performServerShuffle:(NSNotification *)notification
{
    ISMSServerShuffleLoader *loader = [ISMSServerShuffleLoader loaderWithCallbackBlock:^(BOOL success, NSError *error, ISMSLoader *loader)
                                       {
                                           [viewObjectsS hideLoadingScreen];
                                           
                                           if (success)
                                           {
                                               [musicS playSongAtPosition:0];
                                               [self showPlayer];
                                           }
                                           else
                                           {
                                               CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error"
                                                                                                           message:@"There was an error creating the server shuffle list.\n\nThe connection could not be created"
                                                                                                          delegate:self
                                                                                                 cancelButtonTitle:@"OK"
                                                                                                 otherButtonTitles:nil];
                                               [alert show];
                                           }
                                       }];
    
    // Display the loading screen
    [viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
    loader.notification = notification;
    [loader startLoad];
}

- (void)_applicationDidBecomeActive:(NSNotification *)notification
{
    [self _addURLRefBackButton];
}

#pragma mark - Actions -

- (IBAction)a_quickAlbums:(id)sender
{
    QuickAlbumsViewController *quickAlbums = [[QuickAlbumsViewController alloc] init];
    quickAlbums.parent = self;
    quickAlbums.modalPresentationStyle = UIModalPresentationFormSheet;
    
    UIViewController *controller = IS_IPAD() ? appDelegateS.ipadRootViewController : self;
    [controller presentViewController:quickAlbums animated:YES completion:nil];
}

- (IBAction)a_serverShuffle:(id)sender
{
    NSDictionary *folders = [SUSRootFoldersDAO folderDropdownFolders];
    
    if (folders == nil || [folders count] == 2)
    {
        [self _performServerShuffle:nil];
    }
    else
    {
        float height = 65.0f;
        height += (float)[folders count] * 44.0f;
        
        if (height > 300.0f)
            height = 300.0f;
        
        FolderPickerDialog *blankDialog = [[FolderPickerDialog alloc] initWithFrame:CGRectMake(0, 0, 300, height)];
        blankDialog.titleLabel.text = @"Folder to Shuffle";
        [blankDialog show];
    }
}

- (IBAction)a_chat:(id)sender
{
    ChatViewController *chat = [[ChatViewController alloc] init];
    [self.navigationController pushViewController:chat animated:YES];
}

- (IBAction)a_settings:(id)sender
{
    [appDelegateS showSettings];
}

- (IBAction)a_jukebox:(id)sender
{
    settingsS.isJukeboxEnabled = !settingsS.isJukeboxEnabled;
    
    UIColor *backgroundColor = nil;
    NSString *notificationName = nil;
    NSString *eventName = nil;
    if (settingsS.isJukeboxEnabled)
    {
        backgroundColor = viewObjectsS.jukeboxColor;
        notificationName = ISMSNotification_JukeboxEnabled;
        eventName = @"JukeboxEnabled";
        
        [audioEngineS.player stop];
        [jukeboxS jukeboxGetInfo];
    }
    else
    {
        backgroundColor = viewObjectsS.windowColor;
        notificationName = ISMSNotification_JukeboxDisabled;
        eventName = @"JukeboxDisabled";
    }
    
    appDelegateS.window.backgroundColor = backgroundColor;
    [NSNotificationCenter postNotificationToMainThreadWithName:notificationName];
    [Flurry logEvent:eventName];
    
    [self _updateJukeboxIcon];
    
    [self _initSongInfo];
}

- (void)a_nowPlaying:(id)sender
{
    iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
    streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
    [self.navigationController pushViewController:streamingPlayerViewController animated:YES];
}

#pragma mark - Progress HUD Cancel -

- (void)cancelLoad
{
    [_connection cancel];
    _connection = nil;
    _receivedData = nil;
    [viewObjectsS hideLoadingScreen];
}

#pragma mark - Private -

- (void)_updateJukeboxIcon
{
    NSString *imageName = nil;
    if (settingsS.isJukeboxEnabled)
    {
        imageName = IS_IPAD() ? @"home-jukebox-on-ipad" : @"home-jukebox-on";
    }
    else
    {
        imageName = IS_IPAD() ? @"home-jukebox-off-ipad" : @"home-jukebox-off";
    }
    [_jukeboxButton setImage:[UIImage imageNamed:imageName] forState:UIControlStateNormal];
}

- (void)_addURLRefBackButton
{
    if (appDelegateS.referringAppUrl && appDelegateS.mainTabBarController.selectedIndex != 4)
    {
        self.navigationItem.leftBarButtonItem = [[UIBarButtonItem alloc] initWithTitle:@"Back"
                                                                                 style:UIBarButtonItemStyleBordered
                                                                                target:appDelegateS
                                                                                action:@selector(backToReferringApp)];
    }
}

- (void)_initSongInfo
{
	ISMSSong *currentSong = playlistS.currentSong ? playlistS.currentSong : playlistS.prevSong;
	
	if (currentSong != nil)
	{		
		_coverArtView.coverArtId = currentSong.coverArtId;
		
		_artistLabel.text = @"";
		_albumLabel.text = @"";
		_songLabel.text = @"";
		
		if (currentSong.artist)
		{
			_artistLabel.text = [currentSong.artist copy];
		}
		
		if (currentSong.album)
		{
			_albumLabel.text = [currentSong.album copy];
		}
		
		if (currentSong.title)
		{
			_songLabel.text = [currentSong.title copy];
		}
	}
	else
	{
		_coverArtView.image = [UIImage imageNamed:@"default-album-art"];
		_artistLabel.text = @"Use the Folders tab to find music";
		_albumLabel.text = @"";
		_songLabel.text = @"";
	}
}

#pragma mark - Search Bar Delgate -

- (void)searchBarTextDidBeginEditing:(UISearchBar *)theSearchBar
{
	// Create search overlay
	_searchOverlay = [[UIView alloc] init];
    CGRect frame;
	if (settingsS.isNewSearchAPI)
	{
        IS_IPAD() ? CGRectMake(0, 86, 1024, 1024) : CGRectMake(0, 82, 480, 480);
	}
	else
	{
        IS_IPAD() ? CGRectMake(0, 44, 1024, 1024) : CGRectMake(0, 44, 480, 480);
	}
    _searchOverlay.frame = frame;
	
	_searchOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_searchOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	_searchOverlay.alpha = 0.0;
	[self.view addSubview:_searchOverlay];
		
	_dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[_dismissButton addTarget:_searchBar action:@selector(resignFirstResponder) forControlEvents:UIControlEventTouchUpInside];
	_dismissButton.frame = self.view.bounds;
	_dismissButton.enabled = NO;
	[_searchOverlay addSubview:_dismissButton];
	
	// Animate the segmented control on screen
    [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        if (settingsS.isNewSearchAPI)
        {
            _searchSegment.enabled = YES;
            _searchSegment.alpha = 1;
            _searchSegmentBackground.alpha = 1;
        }
        _searchOverlay.alpha = 1;
        _dismissButton.enabled = YES;
    } completion:nil];
}

- (void)searchBarTextDidEndEditing:(UISearchBar *)theSearchBar
{
	// Animate the segmented control off screen
    [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveEaseOut animations:^{
        if (settingsS.isNewSearchAPI)
        {
            _searchSegment.alpha = 0;
            _searchSegment.enabled = NO;
            _searchSegmentBackground.alpha = 0;
        }
        _searchOverlay.alpha = 0;
        _dismissButton.enabled = NO;
    } completion:nil];
}

- (void)searchBarSearchButtonClicked:(UISearchBar *)theSearchBar
{
	_isSearch = YES;
	
	[_searchBar resignFirstResponder];
	
	NSString *searchTerms = [theSearchBar.text stringByTrimmingLeadingAndTrailingWhitespace];
	
    NSDictionary *parameters = nil;
    NSString *action = nil;
	if (settingsS.isNewSearchAPI)
	{
        // Due to a Subsonic bug, to get good search results, we need to add a * to the end of
        // Latin based languages, but not to unicode languages like Japanese.
        BOOL isLatin = [searchTerms canBeConvertedToEncoding:NSISOLatin1StringEncoding];
		NSString *searchTermsString = isLatin ? [NSString stringWithFormat:@"%@*", searchTerms] : searchTerms;
        
        action = @"search2";
        
        NSString *artistCount = @"0";
        NSString *albumCount = @"0";
        NSString *songCount = @"0";
		if (_searchSegment.selectedSegmentIndex == 0)
		{
            artistCount = @"20";
		}
		else if (_searchSegment.selectedSegmentIndex == 1)
		{
            albumCount = @"20";
		}
		else if (_searchSegment.selectedSegmentIndex == 2)
		{
            songCount = @"20";
		}
		else
		{
            artistCount = @"20";
            albumCount = @"20";
            songCount = @"20";
		}
        
        parameters = @{ @"artistCount" : artistCount,
                        @"albumCount"  : albumCount,
                        @"songCount"   : songCount,
                        @"query"       : n2N(searchTermsString) };
	}
	else
	{
        action = @"search";
        parameters = @{ @"count" : @"20",
                        @"any" : n2N(searchTerms) };
	}
		
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:action parameters:parameters];
    
	_connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (_connection)
	{
		_receivedData = [NSMutableData dataWithLength:0];
		
		// Display the loading screen
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error"
                                                                    message:@"There was an error performing the search.\n\nThe connection could not be created"
                                                                   delegate:self
                                                          cancelButtonTitle:@"OK"
                                                          otherButtonTitles:nil];
		[alert show];
	}
}

#pragma mark - Connection delegate -

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[_receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
	[_receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message;
	if (_isSearch)
	{
		message = [NSString stringWithFormat:@"There was an error completing the search.\n\nError:%@", error.localizedDescription];
	}
	else
	{
		message = [NSString stringWithFormat:@"There was an error creating the server shuffle list.\n\nError:%@", error.localizedDescription];
	}
	
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error"
                                                                message:message
                                                               delegate:self
                                                      cancelButtonTitle:@"OK"
                                                      otherButtonTitles:nil];
	[alert show];
	
	_connection = nil;
	_receivedData = nil;
	
	[viewObjectsS hideLoadingScreen];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{
	if (_isSearch)
	{
		// It's a search
		
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:_receivedData];
		SearchXMLParser *parser = (SearchXMLParser*)[[SearchXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		if (settingsS.isNewSearchAPI && _searchSegment.selectedSegmentIndex == 3)
		{
			SearchAllViewController *searchViewController = [[SearchAllViewController alloc] initWithNibName:@"SearchAllViewController" 
																						   bundle:nil];
			searchViewController.listOfArtists = [parser.listOfArtists mutableCopy];
			searchViewController.listOfAlbums = [parser.listOfAlbums mutableCopy];
			searchViewController.listOfSongs = [parser.listOfSongs mutableCopy];
			
			searchViewController.query = [NSString stringWithFormat:@"%@*", _searchBar.text];
						
			[self pushViewControllerCustom:searchViewController];
			
		}
		else
		{
			SearchSongsViewController *searchViewController = [[SearchSongsViewController alloc] initWithNibName:@"SearchSongsViewController" 
																										  bundle:nil];
			searchViewController.title = @"Search";
			if (settingsS.isNewSearchAPI)
			{
				if (_searchSegment.selectedSegmentIndex == 0)
				{
					searchViewController.listOfArtists = [parser.listOfArtists mutableCopy];
				}
				else if (_searchSegment.selectedSegmentIndex == 1)
				{
					searchViewController.listOfAlbums = [parser.listOfAlbums mutableCopy];
				}
				else if (_searchSegment.selectedSegmentIndex == 2)
				{
					searchViewController.listOfSongs = [parser.listOfSongs mutableCopy];
				}
				
				searchViewController.searchType = (ISMSSearchSongsSearchType)_searchSegment.selectedSegmentIndex;
                searchViewController.query = [_searchBar.text stringByAppendingString:@"*"];
			}
			else
			{
				searchViewController.listOfSongs = [parser.listOfSongs mutableCopy];
				searchViewController.searchType = 2;
				searchViewController.query = _searchBar.text;
			}
			
			[self pushViewControllerCustom:searchViewController];
		}
		
		// Hide the loading screen
		[viewObjectsS hideLoadingScreen];
	}
}


@end
