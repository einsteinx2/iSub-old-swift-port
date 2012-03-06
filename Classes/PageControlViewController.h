//
//  PageControlViewController.h
//  iSub
//
//  Created by Ben Baron on 4/7/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class PagingScrollView;
@interface PageControlViewController : UIViewController <UIScrollViewDelegate>
{
}

@property (retain) IBOutlet UIScrollView *scrollView;
@property (retain) IBOutlet UIPageControl *pageControl;
@property (retain) IBOutlet UIView *pageControlHolder;
@property (retain) NSMutableArray *viewControllers;
@property NSUInteger numberOfPages;
@property BOOL pageControlUsed;

@property (retain) UISwipeGestureRecognizer *swipeDetector;


- (IBAction)changePage:(id)sender;
- (void)hideSongInfo;
- (void)resetScrollView;

@end
