//
//  ModalAlbumArtViewController.m
//  iSub
//
//  Created by bbaron on 11/13/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ModalAlbumArtViewController.h"
#import "AsynchronousImageView.h"
#import "DatabaseSingleton.h"
#import "NSString+md5.h"
#import "iSubAppDelegate.h"
#import "FMDatabaseAdditions.h"

#import "Album.h"
#import "NSString+Additions.h"
#import "UIView+Tools.h"
#import "UIApplication+StatusBar.h"
#import "UIImageView+Reflection.h"
 
@implementation ModalAlbumArtViewController
@synthesize albumArt, artistLabel, albumLabel, myAlbum, numberOfTracks, albumLength, durationLabel, trackCountLabel, labelHolderView, albumArtReflection;

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	if (!IS_IPAD())
	{
		[UIView beginAnimations:@"rotate" context:nil];
		//[UIView setAnimationDelegate:self];
		//[UIView setAnimationDidStopSelector:@selector(textScrollingStopped)];
		[UIView setAnimationDuration:duration];
		
		if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
		{
			albumArt.width = 480;
			albumArt.height = 320;
			labelHolderView.alpha = 0.0;
			
		}
		else
		{
			albumArt.width = 320;
			albumArt.height = 320;
			labelHolderView.alpha = 1.0;
		}
		
		[UIView commitAnimations];
	}
}

- (id)initWithAlbum:(Album *)theAlbum numberOfTracks:(NSUInteger)tracks albumLength:(NSUInteger)length
{
	if ((self = [super initWithNibName:@"ModalAlbumArtViewController" bundle:nil]))
	{
		if ([self respondsToSelector:@selector(setModalPresentationStyle:)])
			self.modalPresentationStyle = UIModalPresentationFormSheet;
		
		myAlbum = [theAlbum copy];
		numberOfTracks = tracks;
		albumLength = length;
	}
	
	return self;
}

- (void)viewDidLoad
{	
	if (IS_IPAD())
	{
		// Fix album art size for iPad
		albumArt.width = 540;
		albumArt.height = 540;
		labelHolderView.height = 80;
		labelHolderView.y = 380;
	}
	
	[UIApplication setStatusBarHidden:YES withAnimation:YES];
	
	artistLabel.text = myAlbum.artistName;
	albumLabel.text = myAlbum.title;
	durationLabel.text = [NSString formatTime:albumLength];
	trackCountLabel.text = [NSString stringWithFormat:@"%i Tracks", numberOfTracks];
	if (numberOfTracks == 1)
		trackCountLabel.text = [NSString stringWithFormat:@"%i Track", numberOfTracks];
	
	DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
	
	if(myAlbum.coverArtId)
	{		
		FMDatabase *db = IS_IPAD() ? databaseControls.coverArtCacheDb540 : databaseControls.coverArtCacheDb320;
		
		if ([db intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [myAlbum.coverArtId md5]])
		{
			NSData *imageData = [db dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [myAlbum.coverArtId md5]];
			albumArt.image = [UIImage imageWithData:imageData];
		}
		else 
		{
			[albumArt loadImageFromCoverArtId:myAlbum.coverArtId isForPlayer:NO];
		}
	}
	else 
	{
		albumArt.image = [UIImage imageNamed:@"default-album-art.png"];
	}
	
	albumArtReflection.image = [albumArt reflectedImageWithHeight:albumArtReflection.height];
}

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Overriden to allow any orientation.
    return YES;
}

- (IBAction)dismiss:(id)sender
{
	[UIApplication setStatusBarHidden:NO withAnimation:YES];
	[self dismissModalViewControllerAnimated:YES];
}

- (void)didReceiveMemoryWarning 
{
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
	[albumArt release];
	[albumLabel release];
	[artistLabel release];
	[trackCountLabel release];
	[durationLabel release];
	[labelHolderView release];
	[myAlbum release];
    [super dealloc];
}

@end
