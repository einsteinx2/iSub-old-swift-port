//
//  QuickAlbumsViewController.m
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "QuickAlbumsViewController.h"
#import "HomeAlbumViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "HomeXMLParser.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "NSMutableURLRequest+SUS.h"
#import "UIView+Tools.h"
#import "iPadRootViewController.h"
#import "StackScrollViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "NSNotificationCenter+MainThread.h"

@interface QuickAlbumsViewController (Private)
- (void)albumLoad:(NSString*)modifier;
@end

@implementation QuickAlbumsViewController

@synthesize parent, connection, receivedData, modifier;
@synthesize randomButton, frequentButton, newestButton, recentButton, cancelButton;

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)willRotateToInterfaceOrientation:(UIInterfaceOrientation)toInterfaceOrientation duration:(NSTimeInterval)duration
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:duration];
	
	if (UIInterfaceOrientationIsLandscape(toInterfaceOrientation))
	{
		randomButton.y += 16.;
		frequentButton.y += 16.;
		newestButton.y += 16.;
		recentButton.y += 16.;
		cancelButton.y += 12.;
	}
	else
	{
		randomButton.y -= 16.;
		frequentButton.y -= 16.;
		newestButton.y -= 16.;
		recentButton.y -= 16.;
		cancelButton.y -= 12.;
	}
	
	[UIView commitAnimations];
}

- (id)init
{	
	if ((self = [super initWithNibName:@"QuickAlbumsViewController" bundle:nil]))
    {
        titles = [[NSDictionary alloc] initWithObjectsAndKeys:@"Recently Played", @"recent", @"Frequently Played", @"frequent", @"Newest Albums", @"newest", @"Random Albums", @"random", nil];
    }
	
	return self;
}

- (void)viewDidLoad
{
	[super viewDidLoad];
	
	if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
	{
		randomButton.y += 16.;
		frequentButton.y += 16.;
		newestButton.y += 16.;
		recentButton.y += 16.;
		cancelButton.y += 12.;
	}
}

- (IBAction)random
{
	[self albumLoad:@"random"];
}

- (IBAction)frequent
{
	[self albumLoad:@"frequent"];
}

- (IBAction)newest
{
	[self albumLoad:@"newest"];
}

- (IBAction)recent
{
	[self albumLoad:@"recent"];
}


- (IBAction)cancel
{
	[self dismissModalViewControllerAnimated:YES];
}

- (void)cancelLoad
{
	[self.connection cancel];
	self.connection = nil;
	self.receivedData = nil;
	[viewObjectsS hideLoadingScreen];
}

- (void)albumLoad:(NSString*)theModifier
{		
    self.modifier = theModifier;
    
    NSDictionary *parameters = [NSDictionary dictionaryWithObjectsAndKeys:@"20", @"size", n2N(modifier), @"type", nil];
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getAlbumList" andParameters:parameters];
    
    self.connection = [NSURLConnection connectionWithRequest:request delegate:self];
	if (self.connection)
	{
		self.receivedData = [NSMutableData dataWithCapacity:0];
		
		[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error loading the albums.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
        
        [viewObjectsS hideLoadingScreen];
	}
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

- (void)dealloc 
{
     titles = nil;
}

#pragma mark - Connection Delegate

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
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
    [viewObjectsS hideLoadingScreen];
    
    CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error grabbing the album list.\n\nError:%@", error.localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
    
	self.receivedData = nil;
	self.connection = nil;
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
    HomeAlbumViewController *albumViewController = [[HomeAlbumViewController alloc] initWithNibName:@"HomeAlbumViewController" bundle:nil];
	albumViewController.title = [titles objectForKey:modifier];
	
    NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
    HomeXMLParser *parser = [[HomeXMLParser alloc] initXMLParser];
    [xmlParser setDelegate:parser];
    [xmlParser parse];
    
    albumViewController.listOfAlbums = [NSMutableArray arrayWithArray:parser.listOfAlbums];
    albumViewController.modifier = modifier;
    
    
    self.modifier = nil;
	
	[parent pushViewControllerCustom:albumViewController];
    
	self.receivedData = nil;
	self.connection = nil;
    
    [viewObjectsS hideLoadingScreen];
    [self dismissModalViewControllerAnimated:YES];
}

@end
