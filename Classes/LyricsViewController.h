//
//  LyricsViewController.h
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton;

@interface LyricsViewController : UIViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	UITextView *textView;
}

@property (nonatomic, retain) UITextView *textView;

@end
