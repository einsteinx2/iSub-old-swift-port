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
}

@property (retain) IBOutlet UIScrollView *scrollView;
@property (retain) IBOutlet UIPageControl *pageControl;
@property (retain) IBOutlet UIView *pageControlHolder;
@property (retain) NSMutableArray *viewControllers;
@property NSUInteger numberOfPages;
@property BOOL pageControlUsed;


- (IBAction)changePage:(id)sender;
- (void)showSongInfo;
- (void)hideSongInfo;
- (void)hideSongInfoFast;
- (void)resetScrollView;

@end
