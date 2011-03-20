//
//  FolderDropdownControl.m
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "FolderDropdownControl.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView-tools.h"
#import "iSubAppDelegate.h"
#import "CustomUIAlertView.h"

@implementation FolderDropdownControl
@synthesize tableView, viewsToMove, folders, selectedFolderId;
@synthesize borderColor, textColor, lightColor, darkColor;
@synthesize delegate;

- (id)initWithFrame:(CGRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
		delegate = nil;
		selectedFolderId = -1;
		folders = nil;
		updatedfolders = nil;
		viewsToMove = nil;
		tableView = nil;
		labels = [[NSMutableArray alloc] init];
		isOpen = NO;
		
		borderColor = [[UIColor colorWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1] retain];
		textColor   = [[UIColor colorWithRed:106.0/255.0 green:111.0/255.0 blue:118.0/255.0 alpha:1] retain];
		lightColor  = [[UIColor colorWithRed:206.0/255.0 green:211.0/255.0 blue:218.0/255.0 alpha:1] retain];
		darkColor   = [[UIColor colorWithRed:196.0/255.0 green:201.0/255.0 blue:208.0/255.0 alpha:1] retain];
        //sizeIncrease = 80.0f;
		
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.userInteractionEnabled = YES;
		self.backgroundColor = [UIColor clearColor];
		self.layer.borderColor = borderColor.CGColor;
		self.layer.borderWidth = 2.0;
		self.layer.cornerRadius = 8;
		self.layer.masksToBounds = YES;
		
		selectedFolderLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, self.frame.size.width - 10, 30)];
		selectedFolderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		selectedFolderLabel.userInteractionEnabled = YES;
		selectedFolderLabel.backgroundColor = [UIColor clearColor];
		selectedFolderLabel.textColor = borderColor;
		selectedFolderLabel.textAlignment = UITextAlignmentCenter;
		selectedFolderLabel.font = [UIFont boldSystemFontOfSize:20];
		//selectedFolderLabel.text = @"All Folders";
		[self addSubview:selectedFolderLabel];
		[selectedFolderLabel release];
		
		arrowImage = [[CALayer alloc] init];
		arrowImage.frame = CGRectMake(193, 7, 18, 18);
		arrowImage.contentsGravity = kCAGravityResizeAspect;
		arrowImage.contents = (id)[UIImage imageNamed:@"folder-dropdown-arrow.png"].CGImage;
		[[self layer] addSublayer:arrowImage];
		[arrowImage release];
		
		UIButton *dropdownButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 220, 30)];
		dropdownButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[dropdownButton addTarget:self action:@selector(toggleDropdown:) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:dropdownButton];
		[dropdownButton release];
		
		[self updateFolders];
    }
    return self;
}

- (void)dealloc
{
	[folders release];
	
	[borderColor release];
	[textColor release];
	[lightColor release];
	[darkColor release];
	
	[labels release];
	[viewsToMove release];
    [super dealloc];
}

- (void)setFolders:(NSDictionary *)namesAndIds
{
	// Set the property
	[folders release];
	folders = nil;
	folders = [namesAndIds retain];
	
	// Remove old labels
	for (UILabel *label in labels)
	{
		[label removeFromSuperview];
	}
	[labels removeAllObjects];
	
	sizeIncrease = [folders count] * 30.0f;
	
	NSMutableArray *keys = [NSMutableArray arrayWithArray:[[folders allKeys] sortedArrayUsingSelector:@selector(compare:)]];
	//NSLog(@"keys: %@", keys);
		
	// Process the names and create the labels/buttons
	for (int i = 0; i < [keys count]; i++)
	{
		NSString *folder = [folders objectForKey:[keys objectAtIndex:i]];
		
		CGRect labelFrame  = CGRectMake(0, (i + 1) * 30, self.frame.size.width, 30);
		CGRect buttonFrame = CGRectMake(0, 0, self.frame.size.width - 10, 20);

		UILabel *folderLabel = [[UILabel alloc] initWithFrame:labelFrame];
		folderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		folderLabel.userInteractionEnabled = YES;
		//folderLabel.alpha = 0.0;
		if (i % 2 == 0)
			folderLabel.backgroundColor = lightColor;
		else
			folderLabel.backgroundColor = darkColor;
		folderLabel.textColor = textColor;
		folderLabel.textAlignment = UITextAlignmentCenter;
		folderLabel.font = [UIFont boldSystemFontOfSize:20];
		folderLabel.text = folder;
		folderLabel.tag = [[keys objectAtIndex:i] intValue];
		[self addSubview:folderLabel];
		[labels addObject:folderLabel];
		[folderLabel release];
		
		UIButton *folderButton = [[UIButton alloc] initWithFrame:buttonFrame];
		folderButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[folderButton addTarget:self action:@selector(selectFolder:) forControlEvents:UIControlEventTouchUpInside];
		[folderLabel addSubview:folderButton];
		[folderButton release];
	}
}

- (void)toggleDropdown:(id)sender
{
	if (!isOpen)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
		//[UIView setAnimationDelegate:self];
		//[UIView setAnimationDidStopSelector:@selector(animationStopped)];
		[self.tableView.tableHeaderView addHeight:sizeIncrease];
		[self addHeight:sizeIncrease];
		for (UIView *aView in viewsToMove)
		{
			[aView addY:sizeIncrease];
		}
		for (UILabel *label in labels)
		{
			//label.alpha = 1.0;
		}
		self.tableView.tableHeaderView = self.tableView.tableHeaderView;
		[UIView commitAnimations];
		
		[CATransaction begin];
		[CATransaction setAnimationDuration:.5];
		arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * -60.0f, 0.0f, 0.0f, 1.0f);
		[CATransaction commit];
	}
	else
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.5];
		//[UIView setAnimationDelegate:self];
		//[UIView setAnimationDidStopSelector:@selector(animationStopped)];
		[self.tableView.tableHeaderView addHeight:-sizeIncrease];
		[self addHeight:-sizeIncrease];
		for (UIView *aView in viewsToMove)
		{
			[aView addY:-sizeIncrease];
		}
		for (UILabel *label in labels)
		{
			//label.alpha = 0.0;
		}
		self.tableView.tableHeaderView = self.tableView.tableHeaderView;
		[UIView commitAnimations];
		
		[CATransaction begin];
		[CATransaction setAnimationDuration:.5];
		arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
		[CATransaction commit];
	}
	
	isOpen = !isOpen;
}

- (void)selectFolder:(id)sender
{
	UIButton *button = (UIButton *)sender;
	UILabel  *label  = (UILabel *)button.superview;
	
	NSLog(@"Folder selected: %@ -- %i", label.text, label.tag);
	
	self.selectedFolderId = label.tag;
	selectedFolderLabel.text = [folders objectForKey:[NSString stringWithFormat:@"%i", selectedFolderId]];
	[self toggleDropdown:nil];
	
	// Save the default
	iSubAppDelegate *appDelegate = [iSubAppDelegate sharedInstance];
	NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
	[appDelegate.settingsDictionary setObject:[NSString stringWithFormat:@"%i", selectedFolderId]
									   forKey:@"selectedMusicFolderId"];
	[defaults setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
	[defaults synchronize];
	
	[delegate performSelector:@selector(loadData:) withObject:[NSString stringWithFormat:@"%i", selectedFolderId]];
}

- (void)selectFolderWithId:(NSUInteger)folderId
{
	self.selectedFolderId = folderId;
	selectedFolderLabel.text = [folders objectForKey:[NSString stringWithFormat:@"%i", selectedFolderId]];
}

/*- (void)animationStopped
{
	if (isOpen)
	{
		for (UILabel *label in labels)
		{
			label.hidden = NO;
		}
	}
}*/

- (void)updateFolders
{
	iSubAppDelegate *appDelegate = [iSubAppDelegate sharedInstance];
	NSString *urlString = [appDelegate getBaseUrl:@"getMusicFolders.view"];
		
	NSURLRequest *request = [NSURLRequest requestWithURL:[NSURL URLWithString:urlString] cachePolicy:NSURLRequestReloadIgnoringLocalAndRemoteCacheData timeoutInterval:kLoadingTimeout];
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
		NSString *message = [NSString stringWithFormat:@"There was an error loading the music folders for the dropdown."];
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
		[alert release];
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
	NSString *message = [NSString stringWithFormat:@"There was an error loading the music folders for the dropdown.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert performSelectorOnMainThread:@selector(show) withObject:nil waitUntilDone:NO];
	[alert release];
	
	[theConnection release];
	[receivedData release];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	[xmlParser setDelegate:self];
	[xmlParser parse];
	[xmlParser release];
	
	[theConnection release];
	[receivedData release];
}

#pragma XMLParser delegate

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	NSLog(@"Error parsing update XML response");
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if([elementName isEqualToString:@"musicFolders"])
	{
		updatedfolders = [[NSMutableDictionary alloc] init];
		
		[updatedfolders setObject:@"All Folders" forKey:@"-1"];
	}
	else if ([elementName isEqualToString:@"musicFolder"])
	{
		NSString *folderId = [attributeDict objectForKey:@"id"];
		NSString *folderName = [attributeDict objectForKey:@"name"];
		
		[updatedfolders setObject:folderName forKey:folderId];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if([elementName isEqualToString:@"musicFolders"])
	{
		self.folders = [NSDictionary dictionaryWithDictionary:updatedfolders];
		
		// Save the default
		iSubAppDelegate *appDelegate = [iSubAppDelegate sharedInstance];
		NSUserDefaults *defaults = [NSUserDefaults standardUserDefaults];
		NSData *foldersData = [NSKeyedArchiver archivedDataWithRootObject:folders];
		[appDelegate.settingsDictionary setObject:foldersData forKey:@"folderDropdownCache"];
		[defaults setObject:appDelegate.settingsDictionary forKey:@"settingsDictionary"];
		[defaults synchronize];
		
		[updatedfolders release];
	}
}

@end
