//
//  ChatViewController.h
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class CustomUITextView, SUSChatDAO;

@interface ChatViewController : CustomUITableViewController <UITextViewDelegate, ISMSLoaderDelegate> 

@property (strong) UIView *headerView;
@property (strong) CustomUITextView *textInput;
@property (strong) UIView *chatMessageOverlay;
@property (strong) UIButton *dismissButton;
@property BOOL isNoChatMessagesScreenShowing;
@property (strong) UIImageView *noChatMessagesScreen;
@property (strong) NSMutableArray *chatMessages;
@property (strong) NSMutableData *receivedData;
@property NSInteger lastCheck;
@property (strong) SUSChatDAO *dataModel;

- (void)cancelLoad;

@end
