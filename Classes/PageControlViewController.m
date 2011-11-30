//
//  PageControlViewController.m
//  iSub
//
//  Created by Ben Baron on 4/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "PageControlViewController.h"
#import "SongInfoViewController.h"
#import "CurrentPlaylistBackgroundViewController.h"
#import "LyricsViewController.h"
#import "DebugViewController.h"
#import "iSubAppDelegate.h"
#import "MusicSingleton.h"
#import "SavedSettings.h"
#import "EqualizerViewController.h"
#import "PagingScrollView.h"

@interface PageControlViewController (PrivateMethods)

- (void)loadScrollViewWithPage:(int)page;
- (void)scrollViewDidScroll:(UIScrollView *)sender;

@end


@implementation PageControlViewController

@synthesize scrollView, pageControl, viewControllers;

// Implement viewDidLoad to do additional setup after loading the view, typically from a nib.
//- (void)viewWillAppear:(BOOL)animated 
- (void)viewDidLoad
{
    //[super viewWillAppear:animated];
	[super viewDidLoad];
	
	[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideSongInfoFast) name:@"hideSongInfoFast" object:nil];
	//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(hideSongInfo) name:@"hideSongInfo" object:nil];
	
	appDelegate = (iSubAppDelegate *)[UIApplication sharedApplication].delegate; 
	
	//if ([[appDelegate.settingsDictionary objectForKey:@"lyricsEnabledSetting"] isEqualToString:@"YES"])
	if ([SavedSettings sharedInstance].isLyricsEnabled)
		numberOfPages = 4;
	else
		numberOfPages = 3;	
	
	//if ([MusicControlsSingleton sharedInstance].currentSongObject)
	//{
	//	isCurrentSong = YES;
	//}
	//else
	//{
	//	isCurrentSong = NO;
	//	numberOfPages -= 1;
	//}
	isCurrentSong = YES;

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
	if (IS_IPAD())
		contentSize = CGSizeMake(540 * numberOfPages, 520);
	else
		contentSize = CGSizeMake(scrollView.bounds.size.width * numberOfPages, scrollView.bounds.size.height - 20);
    scrollView.contentSize = contentSize;
    scrollView.showsHorizontalScrollIndicator = NO;
    scrollView.showsVerticalScrollIndicator = NO;
    scrollView.scrollsToTop = NO;
    scrollView.delegate = self;
	
    pageControl.numberOfPages = numberOfPages;
    pageControl.currentPage = 0;
	
	// Load all the pages for better performance
	for (int i = 0; i < numberOfPages; i++)
	{
		[self loadScrollViewWithPage:i];
	}
	
	// pages are created on demand
    // load the visible page
    // load the page on either side to avoid flashes when the user starts scrolling
	//[self loadScrollViewWithPage:0];
    //[self loadScrollViewWithPage:1];
}

/*- (void)viewWillAppear:(BOOL)animated 
{
	NSLog(@"page control viewWillAppear called");
	[super viewWillAppear:animated];
	[scrollView setContentOffset:CGPointZero animated:YES];
}*/

- (void)resetScrollView
{
	DLog(@"PageControlViewController resetScrollView called");
	[scrollView setContentOffset:CGPointZero animated:YES];
}


- (void)loadScrollViewWithPage:(int)page 
{
    if (page < 0) return;
    if (page >= numberOfPages) return;
	
    // replace the placeholder if necessary
    UIViewController *controller = (UIViewController *) [viewControllers objectAtIndex:page];
    if ((NSNull *)controller == [NSNull null]) 
	{
		if (isCurrentSong == NO)
		{
			page += 1;
			numberOfPages += 1;
		}
		
		if (page == 0)
		{
			controller = [[SongInfoViewController alloc] initWithNibName:@"SongInfoViewController" bundle:nil];
		}
		else if (page == 1)
		{
			if (numberOfPages == 3)
				controller = [[CurrentPlaylistBackgroundViewController alloc] initWithNibName:@"CurrentPlaylistBackgroundViewController" bundle:nil];
			else if (numberOfPages)
				controller = [[CurrentPlaylistBackgroundViewController alloc] initWithNibName:@"CurrentPlaylistBackgroundViewController" bundle:nil];
		}
		else if (page == 2)
		{
			if (numberOfPages == 3)
				controller = [[DebugViewController alloc] initWithNibName:@"DebugViewController" bundle:nil];
			else if (numberOfPages == 4)
				controller = [[LyricsViewController alloc] initWithNibName:nil bundle:nil];
		}
		else if (page == 3)
		{
			if (numberOfPages == 4)
				controller = [[DebugViewController alloc] initWithNibName:@"DebugViewController" bundle:nil];
		}
		
		if (isCurrentSong == NO)
		{
			page -= 1;
			numberOfPages -= 1;
		}

		[viewControllers replaceObjectAtIndex:page withObject:controller];
		[controller release];
    }
	else
	{
		//DLog(@"Not loading view, already loaded");
	}
	
    // add the controller's view to the scroll view
    if (nil == controller.view.superview) 
	{
        //CGRect frame = CGRectMake(0, 0, scrollView.contentSize.width / numberOfPages, scrollView.contentSize.height);
		CGRect frame = scrollView.frame;
        frame.origin.x = frame.size.width * page;
        frame.origin.y = 0;
		//DLog(@"controller.view.frame: %@", NSStringFromCGRect(controller.view.frame));
		
		/*if ([controller isKindOfClass:[LyricsViewController class]] && IS_IPAD())
			frame.origin.x = frame.origin.x + 220;*/
			
		controller.view.frame = frame;
        [scrollView addSubview:controller.view];
    }
}

- (void)unloadScrollViewPage:(NSUInteger)page
{
	UIViewController *controller = (UIViewController *) [viewControllers objectAtIndex:page];
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
		[[NSNotificationCenter defaultCenter] postNotificationName:@"hideEditControls" object:nil];
		
        // do nothing - the scroll was initiated from the page control, not the user dragging
        return;
    }
	
    // Switch the indicator when more than 50% of the previous/next page is visible
    CGFloat pageWidth = scrollView.bounds.size.width;
    int page = floor((scrollView.contentOffset.x - pageWidth / 2) / pageWidth) + 1;
    pageControl.currentPage = page;
	
    // load the visible page and the page on either side of it (to avoid flashes when the user starts scrolling)
    /*[self loadScrollViewWithPage:page - 1];
    [self loadScrollViewWithPage:page];
	[self loadScrollViewWithPage:page + 1];
	
	// Unload uneeded pages
	for (int i = 0; i < [viewControllers count]; i++)
	{
		if (i < page - 1 || i > page + 1)
		{
			[self unloadScrollViewPage:i];
		}
	}*/
	
	// Send a notification so the playlist view hides the edit controls
	[[NSNotificationCenter defaultCenter] postNotificationName:@"hideEditControls" object:nil];
	
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
