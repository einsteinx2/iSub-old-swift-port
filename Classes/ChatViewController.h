//
//  ChatViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "CustomUITextView.h"
#import "SUSLoaderDelegate.h"

@class CustomUITextView, EGORefreshTableHeaderView, SUSChatDAO;

@interface ChatViewController : UITableViewController <UITextViewDelegate, SUSLoaderDelegate> 
{
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

@property (strong) UIImageView *noChatMessagesScreen;
@property (strong) NSMutableArray *chatMessages;

@property NSInteger lastCheck;

@property(assign,getter=isReloading) BOOL reloading;

@property (strong) SUSChatDAO *dataModel;

- (void)cancelLoad;

@end
