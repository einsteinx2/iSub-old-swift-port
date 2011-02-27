//
//  PageControlViewController.h
//  iSub
//
//  Created by Ben Baron on 4/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate;

@interface PageControlViewController : UIViewController <UIScrollViewDelegate>
{
	iSubAppDelegate *appDelegate;
	
	UIScrollView *scrollView;
	UIPageControl *pageControl;
	NSMutableArray *viewControllers;
	
	// To be used when scrolls originate from the UIPageControl
    BOOL pageControlUsed;
	
	NSUInteger numberOfPages;
	BOOL isCurrentSong;
}

@property (nonatomic, retain) IBOutlet UIScrollView *scrollView;
@property (nonatomic, retain) IBOutlet UIPageControl *pageControl;
@property (nonatomic, retain) NSMutableArray *viewControllers;

- (IBAction)changePage:(id)sender;
- (void)showSongInfo;
- (void)hideSongInfo;
- (void)hideSongInfoFast;

@end
