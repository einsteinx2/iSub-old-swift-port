//
//  LyricsViewController.h
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import "SUSLoaderDelegate.h"

@class SUSLyricsDAO;

@interface LyricsViewController : UIViewController //<SUSLoaderDelegate>
{
}

@property (retain) SUSLyricsDAO *dataModel;
@property (retain) UITextView *textView;

- (void)updateLyricsLabel;
@end
