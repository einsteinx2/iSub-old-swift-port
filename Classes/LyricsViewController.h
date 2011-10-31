//
//  LyricsViewController.h
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"

@class iSubAppDelegate, ViewObjectsSingleton, MusicSingleton, DatabaseSingleton, SUSLyricsDAO;

@interface LyricsViewController : UIViewController <SUSLoaderDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
}

@property (nonatomic, retain) SUSLyricsDAO *dataModel;
@property (nonatomic, retain) UITextView *textView;

@end
