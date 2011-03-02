//
//  QuickAlbumsViewController.m
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "QuickAlbumsViewController.h"
#import "HomeAlbumViewController.h"
#import "ASIHTTPRequest.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "HomeXMLParser.h"
#import "CustomUIAlertView.h"

@implementation QuickAlbumsViewController

@synthesize parent;

- (id)init
{
	NSString *name;
	/*if (IS_IPAD())
		name = @"QuickAlbumsViewController~iPad";
	else*/
		name = @"QuickAlbumsViewController";
	
	self = [super initWithNibName:name bundle:nil];
	
	titles = [[NSDictionary alloc] initWithObjectsAndKeys:@"Recently Played", @"recent", @"Frequently Played", @"frequent", @"Newest Albums", @"newest", @"Random Albums", @"random", nil];

	return self;
}

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"])
		return NO;
	
    return YES;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[UIApplication sharedApplication].delegate;
	viewObjects = [ViewObjectsSingleton sharedInstance];
}

- (IBAction)random
{
	[self dismissModalViewControllerAnimated:YES];
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(albumLoad:) withObject:@"random"];
}

- (IBAction)frequent
{
	[self dismissModalViewControllerAnimated:YES];
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(albumLoad:) withObject:@"frequent"];
}

- (IBAction)newest
{
	[self dismissModalViewControllerAnimated:YES];
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(albumLoad:) withObject:@"newest"];
}

- (IBAction)recent
{
	[self dismissModalViewControllerAnimated:YES];
	[viewObjects showLoadingScreenOnMainWindow];
	[self performSelectorInBackground:@selector(albumLoad:) withObject:@"recent"];
}


- (IBAction)cancel
{
	[self dismissModalViewControllerAnimated:YES];
}

- (void)pushViewController:(UIViewController *)viewController
{
	// Hide the loading screen
	[viewObjects hideLoadingScreen];
	
	// Push the view controller
	if (IS_IPAD())
		[appDelegate.homeNavigationController pushViewController:viewController animated:YES];
	else
		[parent.navigationController pushViewController:viewController animated:YES];
}

- (void)albumLoad:(NSString*)modifier
{	
	NSAutoreleasePool *releasePool = [[NSAutoreleasePool alloc] init];
	
	HomeAlbumViewController *albumViewController = [[HomeAlbumViewController alloc] initWithNibName:@"HomeAlbumViewController" bundle:nil];
	albumViewController.title = [titles objectForKey:modifier];
	
	// Parse the XML
	//NSLog(@"%@", [NSString stringWithFormat:@"%@&size=20&type=%@", [appDelegate getBaseUrl:@"getAlbumList.view"], modifier]);
	NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@&size=20&type=%@", [appDelegate getBaseUrl:@"getAlbumList.view"], modifier]];
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	[request startSynchronous];
	if ([request error])
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error grabbing the album list.\n\nError:%@", [request error].localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	}
	else
	{
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:[request responseData]];
		HomeXMLParser *parser = [[HomeXMLParser alloc] initXMLParser];
		[xmlParser setDelegate:parser];
		[xmlParser parse];
		
		albumViewController.listOfAlbums = [NSMutableArray arrayWithArray:parser.listOfAlbums];
		albumViewController.modifier = modifier;
		//if ([albumViewController.listOfAlbums count] < 20)
		//	albumViewController.isMoreAlbums = NO;
		
		[xmlParser release];
		[parser release];
	}
	
	[modifier release];
	[url release];
	
	[self performSelectorOnMainThread:@selector(pushViewController:) withObject:albumViewController waitUntilDone:YES];
	[albumViewController release];	
	
	[releasePool release];
}

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)viewDidUnload {
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
}


- (void)dealloc 
{
    [super dealloc];
	
	[titles release];
}


@end
