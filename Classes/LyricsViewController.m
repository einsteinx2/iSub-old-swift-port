//
//  LyricsViewController.m
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "LyricsViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "DatabaseSingleton.h"
#import "FMDatabaseAdditions.h"
#import "Song.h"
#import "SUSLyricsDAO.h"
#import "PlaylistSingleton.h"

@implementation LyricsViewController

@synthesize textView, dataModel;

#pragma mark - Lifecycle

- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil 
{
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) 
	{		
        
        //dataModel = [[SUSLyricsDAO alloc] initWithDelegate:self];
		dataModel = [[SUSLyricsDAO alloc] init];
		
        // Custom initialization
		self.view = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 300)];
		self.view.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		
		textView = [[UITextView alloc] initWithFrame:CGRectMake(0, 45, 320, 255)];
		textView.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		textView.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
		textView.textColor = [UIColor whiteColor];
		textView.font = [UIFont systemFontOfSize:16.5];
		textView.editable = NO;
        
		/*Song *currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;
        NSString *lyrics = [dataModel lyricsForArtist:currentSong.artist andTitle:currentSong.title];
                
		if (lyrics)
		{
			textView.text = lyrics;
		}
		else
		{
			if (viewObjectsS.isOfflineMode)
			{
				textView.text = @"\n\nNo lyrics found";
			}
			else
			{
				[dataModel loadLyricsForArtist:currentSong.artist andTitle:currentSong.title];
				textView.text = @"\n\nLoading Lyrics...";
			}
		}*/
		[self updateLyricsLabel];
		[self.view addSubview:textView];
		
		UILabel *titleLabel = [[UILabel alloc] initWithFrame:CGRectMake(0, 0, 320, 45)];
		titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		titleLabel.backgroundColor = [UIColor colorWithWhite:0.0 alpha:0.8];
		titleLabel.textColor = [UIColor whiteColor];
		titleLabel.font = [UIFont boldSystemFontOfSize:32];
		titleLabel.textAlignment = UITextAlignmentCenter;
		titleLabel.text = @"Lyrics";
		[self.view addSubview:titleLabel];
    }
    return self;
}

- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLyricsLabel) name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLyricsLabel) name:ISMSNotification_LyricsDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateLyricsLabel) name:ISMSNotification_LyricsFailed object:nil];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
	
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_SongPlaybackStarted object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_LyricsDownloaded object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_LyricsFailed object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
	
	[self.dataModel cancelLoad];
}

- (void)dealloc 
{
	dataModel.delegate = nil;
    [[NSNotificationCenter defaultCenter] removeObserver:self];
}

- (void)updateLyricsLabel
{	
	Song *currentSong = playlistS.currentSong;
	NSString *lyrics = [dataModel loadLyricsForArtist:currentSong.artist andTitle:currentSong.title];
	//DLog(@"lyrics = %@", lyrics);
	if (!lyrics)
		lyrics = @"\n\nNo lyrics found";
	
	textView.text = lyrics;
}

/*#pragma mark - ISMSLoader delegate

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
    textView.text = @"\n\nNo lyrics found";
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
	Song *currentSong = [SUSCurrentPlaylistDAO dataModel].currentSong;
    textView.text = [dataModel lyricsForArtist:currentSong.artist andTitle:currentSong.title];
}*/

@end
