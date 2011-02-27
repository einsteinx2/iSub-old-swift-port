//
//  ChatViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "CustomUITextView.h"

@class iSubAppDelegate, SearchOverlayViewController, ViewObjectsSingleton, MusicControlsSingleton, CustomUITextView, EGORefreshTableHeaderView;

@interface ChatViewController : UITableViewController <UITextViewDelegate> 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	
	UIView *headerView;
	CustomUITextView *textInput;
	
	UIView *chatMessageOverlay;
	UIButton *dismissButton;
	
	BOOL isNoChatMessagesScreenShowing;
	UIImageView *noChatMessagesScreen;
	
	NSMutableArray *chatMessages;
	
	NSInteger lastCheck;
	
	NSMutableData *receivedData;
	
	EGORefreshTableHeaderView *refreshHeaderView;
	BOOL _reloading;
}

@property (nonatomic, retain) UIImageView *noChatMessagesScreen;
@property (nonatomic, retain) NSMutableArray *chatMessages;

@property NSInteger lastCheck;

@property(assign,getter=isReloading) BOOL reloading;


@end
