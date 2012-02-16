//
//  PageControlViewController.h
//  iSub
//
//  Created by Ben Baron on 4/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate;

@class PagingScrollView;
@interface PageControlViewController : UIViewController <UIScrollViewDelegate>
{
	iSubAppDelegate *appDelegate;
	
	PagingScrollView *scrollView;
	UIPageControl *pageControl;
	NSMutableArray *viewControllers;
	
	// To be used when scrolls originate from the UIPageControl
    BOOL pageControlUsed;
	
	NSUInteger numberOfPages;
}

@property (retain) IBOutlet UIScrollView *scrollView;
@property (retain) IBOutlet UIPageControl *pageControl;
@property (retain) NSMutableArray *viewControllers;


- (IBAction)changePage:(id)sender;
- (void)showSongInfo;
- (void)hideSongInfo;
- (void)hideSongInfoFast;
- (void)resetScrollView;

@end
