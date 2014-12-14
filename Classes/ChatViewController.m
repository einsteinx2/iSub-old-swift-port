//
//  ChatViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatViewController.h"
#import "ChatUITableViewCell.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"

@interface ChatViewController() <UITextViewDelegate, ISMSLoaderDelegate>
{
    SUSChatDAO *_dataModel;

    CustomUITextView *_textInput;
    UIView *_chatMessageOverlay;
    UIButton *_dismissButton;
    UIImageView *_noChatMessagesScreen;
    NSMutableArray *_chatMessages;
    NSMutableData *_receivedData;
    
    BOOL _noChatMessagesScreenShowing;
    BOOL _reloading;
}
@end


@implementation ChatViewController

#pragma mark - Rotation -

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if (!IS_IPAD() && _noChatMessagesScreenShowing)
	{
        CGFloat ty = UIInterfaceOrientationIsPortrait(fromInterfaceOrientation) ? 42.0f : -160.0f;
        CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, ty);
        _noChatMessagesScreen.transform = translate;
	}
}

#pragma mark - Life Cycle -

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
    self.edgesForExtendedLayout = UIRectEdgeNone;
    self.automaticallyAdjustsScrollViewInsets = NO;
	
	self.title = @"Chat";
    	
	[self _createDataModel];
}

- (void)_createDataModel
{
    _dataModel = [[SUSChatDAO alloc] initWithDelegate:self];
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	    
	[self loadData];
	
	[Flurry logEvent:@"ChatTab"];
}

- (void)viewWillDisappear:(BOOL)animated
{
	if (_noChatMessagesScreenShowing == YES)
	{
		[_noChatMessagesScreen removeFromSuperview];
		_noChatMessagesScreenShowing = NO;
	}
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc
{
    _dataModel.delegate = nil;
}

#pragma mark - CustomUITableViewController Overrides -

- (UIView *)setupHeaderView
{
    UIView *headerView = [[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 82)];
    headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    headerView.backgroundColor = ISMSHeaderColor;
    
    _textInput = [[CustomUITextView alloc] initWithFrame:CGRectMake(5, 5, 240, 72)];
    _textInput.autoresizingMask = UIViewAutoresizingFlexibleWidth;
    _textInput.font = ISMSRegularFont(16);
    _textInput.delegate = self;
    [headerView addSubview:_textInput];
    
    UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
    sendButton.frame = CGRectMake(252, 11, 60, 60);
    sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
    [sendButton addTarget:self action:@selector(a_sendButton:) forControlEvents:UIControlEventTouchUpInside];
    [sendButton setImage:[UIImage imageNamed:@"comment-write"] forState:UIControlStateNormal];
    [sendButton setImage:[UIImage imageNamed:@"comment-write-pressed"] forState:UIControlStateHighlighted];
    [headerView addSubview:sendButton];
    
    return headerView;
}

- (void)customizeTableView:(UITableView *)tableView
{
    tableView.separatorColor = [UIColor clearColor];
}

- (BOOL)shouldSetupRefreshControl
{
    return YES;
}

- (void)didPullToRefresh
{
    if (!_reloading)
    {
        _reloading = YES;
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
        [self loadData];
    }
}

#pragma mark - Private -

- (void)_showNoChatMessagesScreen
{
	if (!_noChatMessagesScreenShowing)
	{
		_noChatMessagesScreenShowing = YES;
		_noChatMessagesScreen = [[UIImageView alloc] init];
		_noChatMessagesScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
		_noChatMessagesScreen.frame = CGRectMake(40, 100, 240, 180);
		_noChatMessagesScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		_noChatMessagesScreen.image = [UIImage imageNamed:@"loading-screen-image"];
		_noChatMessagesScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = ISMSBoldFont(30);
		textLabel.textAlignment = NSTextAlignmentCenter;
		textLabel.numberOfLines = 0;
		[textLabel setText:@"No Chat Messages\non the\nServer"];
		textLabel.frame = CGRectMake(15, 15, 210, 150);
		[_noChatMessagesScreen addSubview:textLabel];
		
		[self.view addSubview:_noChatMessagesScreen];
		
		if (!IS_IPAD())
		{
			if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			{
				CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, 42.0);
				CGAffineTransform scale = CGAffineTransformMakeScale(0.75, 0.75);
				_noChatMessagesScreen.transform = CGAffineTransformConcat(scale, translate);
			}
		}
	}
}

- (NSString *)_formatDate:(NSInteger)unixtime
{
    NSDate *date = [NSDate dateWithTimeIntervalSince1970:unixtime];
    
    NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
    formatter.dateStyle = kCFDateFormatterShortStyle;
    formatter.timeStyle = kCFDateFormatterShortStyle;
    formatter.locale = [NSLocale currentLocale];
    NSString *formattedDate = [formatter stringFromDate:date];
    
    return formattedDate;
}

#pragma mark - Actions -

- (void)a_sendButton:(id)sender
{
    if ([_textInput.text length] != 0)
    {
        [_textInput resignFirstResponder];
        
        [self setupRightBarButton];
        
        [viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Sending"];
        [_dataModel sendChatMessage:_textInput.text];
        
        _textInput.text = @"";
        [_textInput resignFirstResponder];
    }
}

- (void)a_doneSearching:(id)sender
{
    [_textInput resignFirstResponder];
    
    self.navigationItem.rightBarButtonItem = [self setupRightBarButton];
}

#pragma mark - Loading -

- (void)loadData
{
    [_dataModel startLoad];
    [viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
}

- (void)cancelLoad
{
    [_dataModel cancelLoad];
    [viewObjectsS hideLoadingScreen];
}

- (void)dataSourceDidFinishLoadingNewData
{
    _reloading = NO;
    
    [self.refreshControl endRefreshing];
}

#pragma mark ISMSLoader Delegate

- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error
{
	[viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self dataSourceDidFinishLoadingNewData];
	
	if (error.code == ISMSErrorCode_CouldNotSendChatMessage)
	{
		_textInput.text = [[[error userInfo] objectForKey:@"message"] copy];
	}
}

- (void)loadingFinished:(ISMSLoader*)theLoader
{
    [viewObjectsS hideLoadingScreen];
    
    [self.tableView reloadData];
    [self dataSourceDidFinishLoadingNewData];
}

#pragma mark - UITextView delegate -

- (void)textViewDidBeginEditing:(UITextView *)textView
{
	// Create overlay
	_chatMessageOverlay = [[UIView alloc] init];
	if (IS_IPAD())
		_chatMessageOverlay.frame = CGRectMake(0, 82, 1024, 1024);
	else
		_chatMessageOverlay.frame = CGRectMake(0, 82, 480, 480);
	
	_chatMessageOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	_chatMessageOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	_chatMessageOverlay.alpha = 0.0;
	[self.view addSubview:_chatMessageOverlay];
	
	_dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	_dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[_dismissButton addTarget:self action:@selector(a_doneSearching:) forControlEvents:UIControlEventTouchUpInside];
	_dismissButton.frame = self.view.bounds;
	_dismissButton.enabled = NO;
	[_chatMessageOverlay addSubview:_dismissButton];
	
	// Animate the segmented control on screen
    [UIView animateWithDuration:.5 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        _chatMessageOverlay.alpha = 1;
        _dismissButton.enabled = YES;
    } completion:nil];
	
	//Add the done button.
	self.navigationItem.rightBarButtonItem = [[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone
                                                                                           target:self
                                                                                           action:@selector(a_doneSearching:)];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
	// Animate the segmented control off screen
    [UIView animateWithDuration:.3 delay:0 options:UIViewAnimationOptionCurveLinear animations:^{
        _chatMessageOverlay.alpha = 0;
        _dismissButton.enabled = NO;
    } completion:nil];
}

#pragma mark - Table View Delegate -

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Automatically set the height based on the height of the message text
	ISMSChatMessage *aChatMessage = [_dataModel.chatMessages objectAtIndexSafe:indexPath.row];
    CGSize expectedLabelSize = [aChatMessage.message boundingRectWithSize:CGSizeMake(310,CGFLOAT_MAX)
                                                                  options:NSStringDrawingUsesLineFragmentOrigin
                                                               attributes:@{NSFontAttributeName:ISMSRegularFont(20)}
                                                                  context:nil].size;
	if (expectedLabelSize.height < 40)
		expectedLabelSize.height = 40;
	return (expectedLabelSize.height + 20);
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return [_dataModel.chatMessages count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"ChatCell";
	ChatUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[ChatUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}

	ISMSChatMessage *aChatMessage = [_dataModel.chatMessages objectAtIndexSafe:indexPath.row];
	cell.userNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aChatMessage.user, [self _formatDate:aChatMessage.timestamp]];
	cell.messageLabel.text = aChatMessage.message;
	
	cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
	
    return cell;
}

@end

