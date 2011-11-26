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
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "Album.h"
 
@implementation ModalAlbumArtViewController
@synthesize albumArt;

- (id)initWithAlbum:(Album*)theAlbum
{
	if ((self = [super init]))
	{		
		//iSubAppDelegate *appDelegate = (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
		DatabaseSingleton *databaseControls = [DatabaseSingleton sharedInstance];
		
		self.view.backgroundColor = [UIColor blackColor];
		
		if ([self respondsToSelector:@selector(setModalPresentationStyle:)])
			self.modalPresentationStyle = UIModalPresentationFormSheet;
		albumArt = [[AsynchronousImageView alloc] initWithFrame:CGRectMake(0, 0, 540, 540)];
		[self.view addSubview:albumArt];
		
		UIButton *dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
		dismissButton.frame = CGRectMake(0, 0, 540, 540);
		[dismissButton addTarget:self action:@selector(dismissModalViewControllerAnimated:) forControlEvents:UIControlEventTouchUpInside];
		[self.view addSubview:dismissButton];
		
		UILabel *artistLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 540, 250, 100)];
		//artistLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		artistLabel.backgroundColor = [UIColor clearColor];
		artistLabel.textColor = [UIColor colorWithWhite:.6 alpha:1];
		artistLabel.textAlignment = UITextAlignmentLeft;
		artistLabel.text = theAlbum.artistName;
		artistLabel.font = [UIFont boldSystemFontOfSize:48];
		artistLabel.adjustsFontSizeToFitWidth = YES;
		[self.view addSubview:artistLabel];
		[artistLabel release];
		
		UILabel *albumLabel = [[UILabel alloc] initWithFrame:CGRectMake(260, 540, 275, 100)];
		//albumLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		albumLabel.backgroundColor = [UIColor clearColor];
		albumLabel.textColor = [UIColor colorWithWhite:.6 alpha:1];
		albumLabel.textAlignment = UITextAlignmentRight;
		albumLabel.text = theAlbum.title;
		albumLabel.font = [UIFont boldSystemFontOfSize:36];
		albumLabel.adjustsFontSizeToFitWidth = YES;
		[self.view addSubview:albumLabel];
		[albumLabel release];
		
		if ([databaseControls.coverArtCacheDb540 intForQuery:@"SELECT COUNT(*) FROM coverArtCache WHERE id = ?", [theAlbum.coverArtId md5]] == 1)
		{
			NSData *imageData = [databaseControls.coverArtCacheDb540 dataForQuery:@"SELECT data FROM coverArtCache WHERE id = ?", [theAlbum.coverArtId md5]];
			albumArt.image = [UIImage imageWithData:imageData];
		}
		else 
		{
			[albumArt loadImageFromCoverArtId:theAlbum.coverArtId isForPlayer:NO];
			//[albumArt loadImageFromURLString:[NSString stringWithFormat:@"%@%@&size=540", [appDelegate getBaseUrl:@"getCoverArt.view"], coverArtId]];
		}		
	}
	
	return self;
}

 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
/*
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil];
    if (self) {
        // Custom initialization.
    }
    return self;
}
*/

/*
// Implement loadView to create a view hierarchy programmatically, without using a nib.
- (void)loadView {
}
*/

/*
// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad {
    [super viewDidLoad];
}
*/

/*- (void)viewDidAppear:(BOOL)animated
{
	[super viewDidAppear:animated];
	
	self.view.backgroundColor = [UIColor clearColor];
	self.view.frame = CGRectMake(0, 0, 540, 540);
}*/


- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Overriden to allow any orientation.
    return YES;
}


- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc. that aren't in use.
}


- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc {
    [super dealloc];
}


@end
