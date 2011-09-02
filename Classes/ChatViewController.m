//
//  ChatViewController.m
//  iSub
//
//  Created by Ben Baron on 4/2/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ChatViewController.h"
#import "ChatUITableViewCell.h"
#import "ChatXMLParser.h"
#import "ChatMessage.h"
#import "SearchOverlayViewController.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "MusicSingleton.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "AsynchronousImageViewCached.h"
#import "Song.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"
#import "NSString-md5.h"
#import "ASIHTTPRequest.h"
#import "EGORefreshTableHeaderView.h"
#import "NSString-rfcEncode.h"
#import "CustomUIAlertView.h"
#import "SavedSettings.h"

@interface ChatViewController (Private)

- (void)dataSourceDidFinishLoadingNewData;

@end



@implementation ChatViewController

@synthesize noChatMessagesScreen, chatMessages, lastCheck;
@synthesize reloading=_reloading;


-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	//if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] && inOrientation != UIInterfaceOrientationPortrait)
	if ([SavedSettings sharedInstance].isRotationLockEnabled && inOrientation != UIInterfaceOrientationPortrait)
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
			//CGAffineTransform scale = CGAffineTransformMakeScale(0.75, 0.75);
			//noChatMessagesScreen.transform = CGAffineTransformConcat(translate, scale);
			noChatMessagesScreen.transform = translate;
		}
		else
		{
			CGAffineTransform translate = CGAffineTransformMakeTranslation(0.0, -160.0);
			//CGAffineTransform scale = CGAffineTransformMakeScale(1.0, 1.0);
			//noChatMessagesScreen.transform = CGAffineTransformConcat(scale, translate);
			noChatMessagesScreen.transform = translate;
		}
	}
}

- (void)viewDidLoad 
{
    [super viewDidLoad];
	
	appDelegate = (iSubAppDelegate *)[[UIApplication sharedApplication] delegate];
	viewObjects = [ViewObjectsSingleton sharedInstance];
	musicControls = [MusicSingleton sharedInstance];
	
	isNoChatMessagesScreenShowing = NO;
	
	self.tableView.separatorColor = [UIColor clearColor];
	
	self.title = @"Chat";
	//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];

	// Create text input box in header
	headerView = [[[UIView alloc] initWithFrame:CGRectMake(0, 0, 320, 82)] autorelease];
	headerView.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	headerView.backgroundColor = [UIColor colorWithRed:226.0/255.0 green:231.0/255.0 blue:238.0/255.0 alpha:1];
	
	textInput = [[UITextView alloc] initWithFrame:CGRectMake(5, 5, 240, 72)];
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
	//self.tableView.showsVerticalScrollIndicator = YES;
	[refreshHeaderView release];
	
	// Add the table fade
	UIImageView *fadeBottom = [[[UIImageView alloc] initWithImage:[UIImage imageNamed:@"table-fade-bottom.png"]] autorelease];
	fadeBottom.frame = CGRectMake(0, 0, self.tableView.bounds.size.width, 10);
	fadeBottom.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	self.tableView.tableFooterView = fadeBottom;
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
				//noChatMessagesScreen.transform = translate;
				
				//CGAffineTransform translate = CGAffineTransformTranslate(noChatMessagesScreen.transform, 0.0, 42.0);
				//CGAffineTransform scale = CGAffineTransformScale(noChatMessagesScreen.transform, 0.75, 0.75);
				//noChatMessagesScreen.transform = CGAffineTransformConcat(scale, translate);
			}
		}
	}
}


- (void)loadData
{
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:[appDelegate getBaseUrl:@"getChatMessages.view"]] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
	NSURLConnection *connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		receivedData = [[NSMutableData data] retain];
	} 
	else 
	{
		// Inform the user that the connection failed.
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error retreiving the chat messages.\n\nCould not create the network request." delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
	
		[self dataSourceDidFinishLoadingNewData];
	}
}


- (void)viewWillAppear:(BOOL)animated 
{
    [super viewWillAppear:animated];
	
	if(musicControls.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
	
	[viewObjects showLoadingScreenOnMainWindow];
	[self loadData];
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

- (void)viewDidUnload {
	// Release any retained subviews of the main view.
	// e.g. self.myOutlet = nil;
}


- (void) settingsAction:(id)sender 
{
	ServerListViewController *serverListViewController = [[ServerListViewController alloc] initWithNibName:@"ServerListViewController" bundle:nil];
	serverListViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:serverListViewController animated:YES];
	[serverListViewController release];
}


- (IBAction)nowPlayingAction:(id)sender
{
	musicControls.isNewSong = NO;
	iPhoneStreamingPlayerViewController *streamingPlayerViewController = [[iPhoneStreamingPlayerViewController alloc] initWithNibName:@"iPhoneStreamingPlayerViewController" bundle:nil];
	streamingPlayerViewController.hidesBottomBarWhenPushed = YES;
	[self.navigationController pushViewController:streamingPlayerViewController animated:YES];
	[streamingPlayerViewController release];
}


#pragma mark Table view methods

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath 
{
	// Automatically set the height based on the height of the message text
	ChatMessage *aChatMessage = [viewObjects.chatMessages objectAtIndex:indexPath.row];
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
    return [viewObjects.chatMessages count];
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
    static NSString *CellIdentifier = @"Cell";
	ChatUITableViewCell *cell = [[[ChatUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
    // Set up the cell...
	ChatMessage *aChatMessage = [viewObjects.chatMessages objectAtIndex:indexPath.row];
	cell.userNameLabel.text = [NSString stringWithFormat:@"%@ - %@", aChatMessage.user, [self formatDate:aChatMessage.timestamp]];
	cell.messageLabel.text = aChatMessage.message;
	
	cell.backgroundView = [[[UIView alloc] init] autorelease];
	if(indexPath.row % 2 == 0)
	{
		cell.backgroundView.backgroundColor = viewObjects.lightNormal;
	}
	else
	{
		cell.backgroundView.backgroundColor = viewObjects.darkNormal;
	}
	cell.selectionStyle = UITableViewCellSelectionStyleNone;
	
    return cell;
}


- (void)sendButtonAction
{
	if ([textInput.text length] != 0)
	{
		[textInput resignFirstResponder];
		
		//self.navigationItem.leftBarButtonItem = nil;
		//self.navigationItem.leftBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"gear.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(settingsAction:)] autorelease];	
		
		if(musicControls.showPlayerIcon)
		{
			self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
		}
		else
		{
			self.navigationItem.rightBarButtonItem = nil;
		}
		
		
		[viewObjects showLoadingScreenOnMainWindow];
		[self performSelectorInBackground:@selector(sendChatMessage) withObject:nil];
	}
}


- (void) sendChatMessage
{
	// Create an autorelease pool because this method runs in a background thread and can't use the main thread's pool
	NSAutoreleasePool *autoreleasePool = [[NSAutoreleasePool alloc] init];
	
	// Form the URL and send the message
	NSString *encodedMessage = [textInput.text stringByAddingRFC3875PercentEscapesUsingEncoding:NSUTF8StringEncoding]; //(NSString *)CFURLCreateStringByAddingPercentEscapes(NULL, (CFStringRef).text, NULL, (CFStringRef)@"!*'\"();:@&=+$,/?%#[]% ", kCFStringEncodingUTF8 );
	NSURL *url = [[NSURL alloc] initWithString:[NSString stringWithFormat:@"%@%@", [appDelegate getBaseUrl:@"addChatMessage.view"], encodedMessage]];
	ASIHTTPRequest *request = [ASIHTTPRequest requestWithURL:url];
	[request startSynchronous];
	if ([request error])
	{
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:@"There was an error posting the message." delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
		
		// Hide the loading screen
		[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
	}
	else
	{
		// Hide the loading screen
		//[viewObjects performSelectorOnMainThread:@selector(hideLoadingScreen) withObject:nil waitUntilDone:YES];
		
		// Connection worked, reload the table
		[self performSelectorOnMainThread:@selector(loadData) withObject:nil waitUntilDone:NO];
	}
	[url release];
	
	[textInput performSelectorOnMainThread:@selector(setText:) withObject:@"" waitUntilDone:NO];
	[textInput performSelectorOnMainThread:@selector(resignFirstResponder) withObject:nil waitUntilDone:NO];
	
	[autoreleasePool release];
}


#pragma mark UITextView delegate methods

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
	
	if(musicControls.showPlayerIcon)
	{
		self.navigationItem.rightBarButtonItem = [[[UIBarButtonItem alloc] initWithImage:[UIImage imageNamed:@"now-playing.png"] style:UIBarButtonItemStyleBordered target:self action:@selector(nowPlayingAction:)] autorelease];
	}
	else
	{
		self.navigationItem.rightBarButtonItem = nil;
	}
}


#pragma mark Connection Delegate

- (BOOL)connection:(NSURLConnection *)connection canAuthenticateAgainstProtectionSpace:(NSURLProtectionSpace *)space 
{
	if([[space authenticationMethod] isEqualToString:NSURLAuthenticationMethodServerTrust]) 
		return YES; // Self-signed cert will be accepted
	
	return NO;
}

- (void)connection:(NSURLConnection *)connection didReceiveAuthenticationChallenge:(NSURLAuthenticationChallenge *)challenge
{	
	if([challenge.protectionSpace.authenticationMethod isEqualToString:NSURLAuthenticationMethodServerTrust])
	{
		[challenge.sender useCredential:[NSURLCredential credentialForTrust:challenge.protectionSpace.serverTrust] forAuthenticationChallenge:challenge]; 
	}
	[challenge.sender continueWithoutCredentialForAuthenticationChallenge:challenge];
}

- (void)connection:(NSURLConnection *)connection didReceiveResponse:(NSURLResponse *)response
{
	[receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error retreiving the chat messages.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[theConnection release];
	[receivedData release];
	
	[viewObjects hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	viewObjects.chatMessages = [NSMutableArray arrayWithCapacity:1];
	//viewObjects.chatMessages = nil, viewObjects.chatMessages = [[NSMutableArray alloc] init];
	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	ChatXMLParser *parser = [[ChatXMLParser alloc] initXMLParser];
	[xmlParser setDelegate:parser];
	[xmlParser parse];
		
	[xmlParser release];
	[parser release];
	
	[self.tableView reloadData]; 
	
	if ([viewObjects.chatMessages count] == 0)
	{
		[self showNoChatMessagesScreen];
	}
	else
	{
		if (isNoChatMessagesScreenShowing == YES)
		{
			isNoChatMessagesScreenShowing = NO;
			[noChatMessagesScreen removeFromSuperview];
		}
	}
	
	[viewObjects hideLoadingScreen];
	[self dataSourceDidFinishLoadingNewData];
	
	[theConnection release];
	[receivedData release];
}

#pragma mark -
#pragma mark Pull to refresh methods

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
		[viewObjects showLoadingScreenOnMainWindow];
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
    [super dealloc];
}


@end

