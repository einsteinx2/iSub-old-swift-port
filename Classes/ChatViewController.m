//
//  ChatViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatViewController.h"
#import "ChatUITableViewCell.h"
#import "ChatMessage.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AsynchronousImageView.h"
#import "Song.h"
#import "FMDatabaseAdditions.h"
#import "NSString+md5.h"
#import "EGORefreshTableHeaderView.h"
#import "NSString+rfcEncode.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"
#import "SUSChatDAO.h"
#import "NSError+ISMSError.h"
#import "FlurryAnalytics.h"
#import "SeparaterView.h"
#import "NSArray+Additions.h"

@interface ChatViewController (Private)
- (void)dataSourceDidFinishLoadingNewData;
@end


@implementation ChatViewController

@synthesize noChatMessagesScreen, chatMessages, lastCheck;
@synthesize reloading=_reloading;
@synthesize dataModel;

#pragma mark - Rotation

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if (settingsS.isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	if (!IS_IPAD() && isNoChatMessagesScreenShowing)
	{
		if (UIInterfaceOrientationIsPortrait(fromInterfaceOrientation))
		{
			CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, 42.0);
			noChatMessagesScreen.transform = translate;
		}
		else
		{
			CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, -160.0);
			noChatMessagesScreen.transform = translate;
		}
	}
}

#pragma mark - Life Cycle

- (void)createDataModel
{
	self.dataModel = [[[SUSChatDAO alloc] initWithDelegate:self] autorelease];
}

- (void)loadData
{
	[self.dataModel startLoad];
	[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
}

- (void)cancelLoad
{
	[self.dataModel cancelLoad];
	[viewObjectsS hideLoadingScreen];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	
	isNoChatMessagesScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Chat";

	// Create text input box in header
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 82)] autorelease];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	CGRect sepFrame = CGRectMake(0, 0, headerView.bounds.size.width, 2);
	SeparaterView *sepView = [[SeparaterView alloc] initWithFrame:sepFrame];
	[headerView addSubview:sepView];
	[sepView release];
	
	textInput = [[CustomUITextView alloc] initWithFrame:CGRectMake(5, 5, 240, 72)];
	textInput.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	textInput.font = [UIFont systemFontOfSize:16];
	textInput.delegate = self;
	[headerView addSubview:textInput];
	[textInput release];
	
	UIButton *sendButton = [UIButton buttonWithType:UIButtonTypeCustom];
	sendButton.frame = CGRectMake(252, 11, 60, 60);
	sendButton.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	[sendButton addTarget:self action:@selector(sendButtonAction) forControlEvents:UIControlEventTouchUpInside];
	[sendButton setImage:[UIImage imageNamed:@"comment-write.png"] forState:UIControlStateNormal];
	[sendButton setImage:[UIImage imageNamed:@"comment-write-pressed.png"] forState:UIControlStateHighlighted];
	[headerView addSubview:sendButton];
	
	self.tableView.tableHeaderView = headerView;

	// Add the pull to refresh view
	refreshHeaderView = [[EGORefreshTableHeaderView alloc] initWithFrame:CGRectMake(0.0f, 0.0f - self.tableView.bounds.size.height, 320.0f, self.tableView.bounds.size.height)];
	refreshHeaderView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:237.0/255.0 alpha:1.0];
	[self.tableView addSubview:refreshHeaderView];
	[refreshHeaderView release];
	
	if (IS_IPAD())
	{
		self.view.backgroundColor = ISMSiPadBackgroundColor;
	}
	//else
	//{
		// Add the table fade
		UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
		fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
		fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.tableView.tableFooterView = fadeBottom;
	//}
	
	[self createDataModel];
}

- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
		
	[self loadData];
	
	[FlurryAnalytics logEvent:@"ChatTab"];
}

-(void)viewWillDisappear:(BOOL)animated
{
	if (isNoChatMessagesScreenShowing == YES)
	{
		[noChatMessagesScreen removeFromSuperview];
		isNoChatMessagesScreenShowing = NO;
	}
}


- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)showNoChatMessagesScreen
{
	if (isNoChatMessagesScreenShowing == NO)
	{
		isNoChatMessagesScreenShowing = YES;
		noChatMessagesScreen = [[UIImageView alloc] init];
		noChatMessagesScreen.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin | UIViewAutoresizingFlexibleBottomMargin | UIViewAutoresizingFlexibleRightMargin | UIViewAutoresizingFlexibleTopMargin;
		noChatMessagesScreen.frame = CGRectMake(40, 100, 240, 180);
		noChatMessagesScreen.center = CGPointMake(self.view.bounds.size.width / 2, self.view.bounds.size.height / 2);
		noChatMessagesScreen.image = [UIImage imageNamed:@"loading-screen-image.png"];
		noChatMessagesScreen.alpha = .80;
		
		UILabel *textLabel = [[UILabel alloc] init];
		textLabel.backgroundColor = [UIColor clearColor];
		textLabel.textColor = [UIColor whiteColor];
		textLabel.font = [UIFont boldSystemFontOfSize:32];
		textLabel.textAlignment = UITextAlignmentCenter;
		textLabel.numberOfLines = 0;
		[textLabel setText:@"No Chat Messages\non the\nServer"];
		textLabel.frame = CGRectMake(15, 15, 210, 150);
		[noChatMessagesScreen addSubview:textLabel];
		[textLabel release];
		
		[self.view addSubview:noChatMessagesScreen];
		
		[noChatMessagesScreen release];
		
		if (!IS_IPAD())
		{
			if (UIInterfaceOrientationIsLandscape(self.interfaceOrientation))
			{
				CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, 42.0);
				CGAffineTransform scale = CGAffineTransformMakeScale(0.75, 0.75);
				noChatMessagesScreen.transform = CGAffineTransformConcat(scale, translate);
			}
		}
	}
}

#pragma mark - Button handling

- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
	[serverListViewController release];
}

- (IBAction)nowPlayingAction:(id)sender
{
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}

#pragma mark - SUSLoader delegate

- (void)loadingFailed:(SUSLoader*)theLoader withError:(NSError *)error
{
	[viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self dataSourceDidFinishLoadingNewData];
	
	if ([error code] == ISMSErrorCode_CouldNotSendChatMessage)
	{
		textInput.text = [[[[error userInfo] objectForKey:@"message"] copy] autorelease];
	}
}

- (void)loadingFinished:(SUSLoader*)theLoader
{
	[viewObjectsS hideLoadingScreen];
	
	[self.tableView reloadData];
	[self dataSourceDidFinishLoadingNewData];
}

#pragma mark - UITextView delegate

- (void)textViewDidBeginEditing:(UITextView *)textView
{
	// Create overlay
	chatMessageOverlay = [[UIView alloc] init];
	if (IS_IPAD())
		chatMessageOverlay.frame = CGRectMake(0, 82, 1024, 1024);
	else
		chatMessageOverlay.frame = CGRectMake(0, 82, 480, 480);
	
	chatMessageOverlay.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	chatMessageOverlay.backgroundColor = [UIColor colorWithWhite:0 alpha:.80];
	chatMessageOverlay.alpha = 0.0;
	[self.view addSubview:chatMessageOverlay];
	[chatMessageOverlay release];
	
	dismissButton = [UIButton buttonWithType:UIButtonTypeCustom];
	dismissButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
	[dismissButton addTarget:self action:@selector(doneSearching_Clicked:) forControlEvents:UIControlEventTouchUpInside];
	dismissButton.frame = self.view.bounds;
	dismissButton.enabled = NO;
	[chatMessageOverlay addSubview:dismissButton];
	
	// Animate the segmented control on screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.5];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	chatMessageOverlay.alpha = 1;
	dismissButton.enabled = YES;
	[UIView commitAnimations];
	
	
	//Add the done button.
	self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithBarButtonSystemItem:UIBarButtonSystemItemDone target:self action:@selector(doneSearching_Clicked:)] autorelease];
}

- (void)textViewDidEndEditing:(UITextView *)textView
{
	// Animate the segmented control off screen
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[UIView setAnimationCurve:UIViewAnimationCurveLinear];
	chatMessageOverlay.alpha = 0;
	dismissButton.enabled = NO;
	[UIView commitAnimations];
}


- (void) doneSearching_Clicked:(id)sender 
{	
	[textInput resignFirstResponder];
	
	if(musicS.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
}

#pragma mark - Table view delegate

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Automatically set the height based on the height of the message text
	ChatMessage *aChatMessage = [dataModel.chatMessages objectAtIndexSafe:indexPath.row];
	CGSize expectedLabelSize = [aChatMessage.message sizeWithFont:[UIFont systemFontOfSize:20] constrainedToSize:CGSizeMake(310,CGFLOAT_MAX) lineBreakMode:UILineBreakModeWordWrap];
	if (expectedLabelSize.height < 40)
		expectedLabelSize.height = 40;
	return (expectedLabelSize.height + 20);
}


- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}


// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
    return [dataModel.chatMessages count];
}


- (NSString *)formatDate:(NSInteger)unixtime
{
	NSDate *date = [NSDate dateWithTimeIntervalSince1970:unixtime];
	
	NSDateFormatter *formatter = [[NSDateFormatter alloc] init];
	formatter.dateStyle = kCFDateFormatterShortStyle;
	formatter.timeStyle = kCFDateFormatterShortStyle;
	formatter.locale = [NSLocale currentLocale];
	NSString *formattedDate = [formatter stringFromDate:date];
	[formatter release];
	
	return formattedDate;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	static NSString *cellIdentifier = @"ChatCell";
	ChatUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
	if (!cell)
	{
		cell = [[ChatUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.selectionStyle = UITableViewCellSelectionStyleNone;
	}

    // Set up the cell...
	ChatMessage *aChatMessage = [dataModel.chatMessages objectAtIndexSafe:indexPath.row];
	cell.userNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aChatMessage.user, [self formatDate:aChatMessage.timestamp]];
	cell.messageLabel.text = aChatMessage.message;
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
	{
		cell.backgroundView.backgroundColor = viewObjectsS.lightNormal;
	}
	else
	{
		cell.backgroundView.backgroundColor = viewObjectsS.darkNormal;
	}
	
    return cell;
}


- (void)sendButtonAction
{
	if ([textInput.text length] != 0)
	{
		[textInput resignFirstResponder];

		if(musicS.showPlayerIcon)
		{
			self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
		}
		else
		{
			self.navigationItem.rightBarButtonItem = nil;
		}
		
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:@"Sending"];
		[self.dataModel sendChatMessage:textInput.text];
		
		textInput.text = @"";
		[textInput resignFirstResponder];
	}
}

#pragma mark - Pull to refresh methods

- (void)scrollViewDidScroll:(UIScrollView *)scrollView
{	
	if (scrollView.isDragging) 
	{
		if (refreshHeaderView.state == EGOOPullRefreshPulling && scrollView.contentOffset.y > -65.0f && scrollView.contentOffset.y < 0.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshNormal];
		} 
		else if (refreshHeaderView.state == EGOOPullRefreshNormal && scrollView.contentOffset.y < -65.0f && !_reloading) 
		{
			[refreshHeaderView setState:EGOOPullRefreshPulling];
		}
	}
}

- (void)scrollViewDidEndDragging:(UIScrollView *)scrollView willDecelerate:(BOOL)decelerate
{
	if (scrollView.contentOffset.y <= - 65.0f && !_reloading) 
	{
		_reloading = YES;
		[viewObjectsS showLoadingScreenOnMainWindowWithMessage:nil];
		[self loadData];
		[refreshHeaderView setState:EGOOPullRefreshLoading];
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:0.2];
		self.tableView.contentInset = UIEdgeInsetsMake(60.0f, 0.0f, 0.0f, 0.0f);
		[UIView commitAnimations];
	}
}

- (void)dataSourceDidFinishLoadingNewData
{
	_reloading = NO;
	
	[UIView beginAnimations:nil context:NULL];
	[UIView setAnimationDuration:.3];
	[self.tableView setContentInset:UIEdgeInsetsMake(0.0f, 0.0f, 0.0f, 0.0f)];
	[UIView commitAnimations];
	
	[refreshHeaderView setState:EGOOPullRefreshNormal];
}

- (void)dealloc 
{
	dataModel.delegate = nil;
	[dataModel release]; dataModel = nil;
    [super dealloc];
}


@end

