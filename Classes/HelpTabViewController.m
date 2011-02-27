//
//  HelpTabViewController.m
//  iSub
//
//  Created by Ben Baron on 6/29/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "HelpTabViewController.h"
#import "iSubAppDelegate.h"
#import "Reachability.h"

@implementation HelpTabViewController

@synthesize helpWebView;

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation {
    return YES;
}

/*
 // The designated initializer.  Override if you create the controller programmatically and want to perform customization that is not appropriate for viewDidLoad.
- (id)initWithNibName:(NSString *)nibNameOrNil bundle:(NSBundle *)nibBundleOrNil {
    if ((self = [super initWithNibName:nibNameOrNil bundle:nibBundleOrNil])) {
        // Custom initialization
    }
    return self;
}
*/


// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
- (void)viewDidLoad 
{
    [super viewDidLoad];
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	
	if ([appDelegate.wifiReach currentReachabilityStatus] == NotReachable)
	{
		NSString* embedHTML = @"\
		<html><head>\
		<style type=\"text/css\">\
		body {\
        width: 100%;\
        margin: 0;\
        padding: 0 0 20px 0;\
        background: #111 url(data:image/gif;base64,R0lGODlhAQBKAdUAABEREREREhERExERFBESGRESFxESFRESFhESGBETHhETHRESGhEUJREWNhEUKBEUKREVLREWOBEVLxEVMhETIxESGxETIREUJBETHxETIhEWMxEUKhEVLBEUJhESHBEVMRETIBEWNBEVLhEWNxEUJxEVMBEWNREWOREUKxERFREVKxETHAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAAACH5BAAAAAAALAAAAAABAEoBAAaPwJMwQiyOjseGcmlqmkJQqGZKnVivn2y2xC1JvmCRWAwpmzlotEqFam/e74d87qjbSXh8Z79n+P8XgYIUhIUZh4gWiosgjY0YkJEJk5QJCpeYCisenJwVn6ALoqMLBKanpgiqqwgFrq+uB7KzBwa2twYpKQO8vb4CwMHCAgHFxsfFAMrLzM3Oz9DR0tPUykEAOw==) top left repeat-x;\
        font-size: 1.3em;\
        color: #fff;\
        font-family: Arial, Helvetica, sans-serif;\
		text-align: center;\
		}\
		</style>\
		</head>\
		<body>\
		You must be connected to the Internet to view the help videos.\
		</body></html>";
		[helpWebView loadHTMLString:embedHTML baseURL:nil];
	}
	else
	{	
		NSString *helpUrlString = @"http://isubapp.com/iphoneHelp/index-3.0.html";
		NSURL *helpUrl = [NSURL URLWithString:helpUrlString];
		NSURLRequest *request = [NSURLRequest requestWithURL:helpUrl];
		[helpWebView loadRequest:request];
	}
}


/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/

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


- (void)dealloc {
    [super dealloc];
}


@end
