//
//  PageControlViewController.m
//  iSub
//
//  Created by Ben Baron on 4/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PageControlViewController.h"
#import "CurrentPlaylistBackgroundViewController.h"
#import "LyricsViewController.h"
#import "DebugViewController.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "SavedSettings.h"
#import "EqualizerViewController.h"
#import "PagingScrollView.h"
#import "NSArray+Additions.h"
#import "UIView+Tools.h"
#import "NSNotificationCenter+MainThread.h"

@interface PageControlViewController (PrivateMethods)

- (void)loadScrollViewWithPage:(int)page;
- (void)scrollViewDidScroll:(UIScrollView *)sender;

@end


@implementation PageControlViewController

@synthesize scrollView, pageControl, viewControllers, numberOfPages, pageControlUsed, pageControlHolder;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
//- (void)viewWillAppear:(BOOL)animated 
- (void)viewDidLoad
{
    //[super viewWillAppear:animated];
	[super viewDidLoad];
	
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideSongInfoFast) name:@"hideSongInfoFast" object:nil];
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideSongInfo) name:@"hideSongInfo" object:nil];
		
	numberOfPages = 1;
	if (settingsS.isLyricsEnabled) numberOfPages++;
	if (settingsS.isCacheStatusEnabled) numberOfPages++;
	
	// view controllers are created lazily
    // in the meantime, load the array with placeholders which will be replaced on demand
    NSMutableArray *controllers = [[NSMutableArray alloc] init];
    for (unsigned i = 0; i < numberOfPages; i++) {
        [controllers addObject:[NSNull null]];
    }
    self.viewControllers = controllers;
    [controllers release];
	
	// a page is the width of the scroll view
    scrollView.pagingEnabled = YES;
	CGSize contentSize;
	CGFloat height;
	//if (IS_IPAD())
	//	contentSize = CGSizeMake(540 * numberOfPages, 520);
	//else
	{
		if (UIInterfaceOrientationIsPortrait([UIApplication sharedApplication].statusBarOrientation) || IS_IPAD())
		{
			contentSize = CGSizeMake(320 * numberOfPages, numberOfPages == 1 ? 320 : 300);
			height = numberOfPages == 1 ? 320 : 300;
		}
		else
		{
			contentSize = CGSizeMake(300 * numberOfPages, numberOfPages == 1 ? 270 : 250);
			height = numberOfPages == 1 ? 270 : 250;
		}
	}
	scrollView.height = height;
    scrollView.contentSize = contentSize;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.scrollsToTop = NO;
    scrollView.delegate = self;
	
    pageControl.numberOfPages = numberOfPages;
    pageControl.currentPage = 0;
	
	if (numberOfPages == 1)
	{
		pageControlHolder.hidden = YES;
		pageControl.hidden = YES;
	}
	
	// Load all the pages for better performance
	/*for (int i = 0; i < numberOfPages; i++)
	{
		[self loadScrollViewWithPage:i];
	}*/
	
	// pages are created on demand
    // load the visible page
    // load the page on either side to avoid flashes when the user starts scrolling
	[self loadScrollViewWithPage:0];
    [self loadScrollViewWithPage:1];
}

- (void)resetScrollView
{
	DLog(@"PageControlViewController resetScrollView called");
	[scrollView setContentOffset:CGPointZero animated:YES];
}


- (void)loadScrollViewWithPage:(int)page 
{
    if (page < 0) return;
    if (page >= numberOfPages) return;
	
	UIViewController *controller = (UIViewController *) [viewControllers objectAtIndexSafe:page];
    if ((NSNull *)controller != [NSNull null]) return; 

	
    // Replace the placeholder
	switch (page) 
	{
		case 0:
			controller = [[CurrentPlaylistBackgroundViewController alloc] initWithNibName:@"CurrentPlaylistBackgroundViewController" bundle:nil];
			break;
		case 1:
			if (settingsS.isLyricsEnabled)
				controller = [[LyricsViewController alloc] initWithNibName:nil bundle:nil];
			else if (settingsS.isCacheStatusEnabled)
				controller = [[DebugViewController alloc] initWithNibName:@"DebugViewController" bundle:nil];
			break;
		case 2:
			controller = [[DebugViewController alloc] initWithNibName:@"DebugViewController" bundle:nil];
		default:
			break;
	}
	
	[viewControllers replaceObjectAtIndex:page withObject:controller];
	[controller release];
	
    // Add the controller's view to the scroll view
	CGRect frame = scrollView.frame;
	frame.origin.x = frame.size.width * page;
	frame.origin.y = 0;
	controller.view.frame = frame;
	[scrollView addSubview:controller.view];
}

- (void)unloadScrollViewPage:(NSUInteger)page
{
	UIViewController *controller = (UIViewController *) [viewControllers objectAtIndexSafe:page];
	if ((NSNull *)controller != [NSNull null])
	{
		[controller.view removeFromSuperview];
		[viewControllers replaceObjectAtIndex:page withObject:[NSNull null]];
	}
}

- (void)scrollViewDidScroll:(UIScrollView *)sender 
{
    // We don't want a "feedback loop" between the UIPageControl and the scroll delegate in
    // which a scroll event generated from the user hitting the page control triggers updates from
    // the delegate method. We use a boolean to disable the delegate logic when the page control is used.
    if (pageControlUsed) 
	{
		// Send a notification so the playlist view hides the edit controls
		[NSNotificationCenter postNotificationToMainThreadWithName:@"hideEditControls"];
		
        // do nothing - the scroll was initiated from the page control, not the user dragging
        return;
    }
	
    // Switch the indicator when more than 50% of the previous/next page is visible
    CGFloat pageWidth = scrollView.bounds.size.width;
    int page = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    pageControl.currentPage = page;
	
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    [self loadScrollViewWithPage:page - 1];
    [self loadScrollViewWithPage:page];
	[self loadScrollViewWithPage:page + 1];
	
	/*// Unload uneeded pages
	for (int i = 0; i < [viewControllers count]; i++)
	{
		if (i < page - 1 || i > page + 1)
		{
			[self unloadScrollViewPage:i];
		}
	}*/
	
	// Send a notification so the playlist view hides the edit controls
	[NSNotificationCenter postNotificationToMainThreadWithName:@"hideEditControls"];
	
    // A possible optimization would be to unload the views+controllers which are no longer visible
}


// At the begin of scroll dragging, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewWillBeginDragging:(UIScrollView *)scrollView {
    pageControlUsed = NO;
}


// At the end of scroll animation, reset the boolean used when scrolls originate from the UIPageControl
- (void)scrollViewDidEndDecelerating:(UIScrollView *)scrollView {
    pageControlUsed = NO;
}


- (IBAction)changePage:(id)sender 
{
    int page = pageControl.currentPage;
	
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    [self loadScrollViewWithPage:page - 1];
    [self loadScrollViewWithPage:page];
    [self loadScrollViewWithPage:page + 1];
    
	// update the scroll view to the appropriate page
    CGRect frame = scrollView.bounds;
    frame.origin.x = frame.size.width * page;
    frame.origin.y = 0;
    [scrollView scrollRectToVisible:frame animated:YES];
    
	// Set the boolean used when scrolls originate from the UIPageControl. See scrollViewDidScroll: above.
    pageControlUsed = YES;
}


- (void) showSongInfo
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.20];
	
	self.view.alpha = 1.0;
}
 
 
- (void) hideSongInfo
{
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.50];
	
	self.view.alpha = 0.0;
	
	[UIView commitAnimations];
}
 
 
- (void) hideSongInfoFast
{	
	[self.view removeFromSuperview];
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)viewDidDisappear:(BOOL)animated
{
	[super viewDidDisappear:animated];
		
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfoFast" object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:@"hideSongInfo" object:nil];
	
	for (UIViewController *subView in viewControllers)
	{
		if ((NSNull*)subView != [NSNull null])
		{
			[subView.view removeFromSuperview];
			//[subView viewDidDisappear:NO];
		}
	}
	
	[viewControllers release]; viewControllers = nil;
}

- (void)dealloc 
{
    [super dealloc];
}

@end
