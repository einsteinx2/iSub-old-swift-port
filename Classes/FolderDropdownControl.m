//
//  FolderDropdownControl.m
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "FolderDropdownControl.h"
#import <QuartzCore/QuartzCore.h>
#import "UIView+tools.h"
#import "iSubAppDelegate.h"
#import "CustomUIAlertView.h"
#import "NSString+md5.h"
#import "SUSRootFoldersDAO.h"
#import "NSMutableURLRequest+SUS.h"
#import "NSArray+Additions.h"
#import "NSArray+Additions.h"

@implementation FolderDropdownControl
@synthesize selectedFolderId, isOpen;
@synthesize borderColor, textColor, lightColor, darkColor;
@synthesize delegate;

- (id)initWithFrame:(CGRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
		delegate = nil;
		selectedFolderId = [[NSNumber numberWithInt:-1] retain];
		folders = [[SUSRootFoldersDAO folderDropdownFolders] retain];
		updatedfolders = nil;
		labels = [[NSMutableArray alloc] init];
		isOpen = NO;
		connection = nil;
		receivedData = nil;
		
		borderColor = [[UIColor colorWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1] retain];
		textColor   = [[UIColor colorWithRed:106.0/255.0 green:111.0/255.0 blue:118.0/255.0 alpha:1] retain];
		lightColor  = [[UIColor colorWithRed:206.0/255.0 green:211.0/255.0 blue:218.0/255.0 alpha:1] retain];
		darkColor   = [[UIColor colorWithRed:196.0/255.0 green:201.0/255.0 blue:208.0/255.0 alpha:1] retain];
		
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
		selectedFolderLabel.text = @"All Folders";
		[self addSubview:selectedFolderLabel];
		[selectedFolderLabel release];
		
		UIView *arrowImageView = [[UIView alloc] initWithFrame:CGRectMake(193, 7, 18, 18)];
		arrowImageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self addSubview:arrowImageView];
		[arrowImageView release];
		
		arrowImage = [[CALayer alloc] init];
		arrowImage.frame = CGRectMake(0, 0, 18, 18);
		arrowImage.contentsGravity = kCAGravityResizeAspect;
		arrowImage.contents = (id)[UIImage imageNamed:@"folder-dropdown-arrow.png"].CGImage;
		[[arrowImageView layer] addSublayer:arrowImage];
		[arrowImage release];
		
		UIButton *dropdownButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 220, 30)];
		dropdownButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[dropdownButton addTarget:self action:@selector(toggleDropdown:) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:dropdownButton];
		[dropdownButton release];
		
		[self updateFolders];
		
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFolders) name:ISMSNotification_ServerCheckPassed object:nil];
		[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverSwitched) name:ISMSNotification_ServerSwitched object:nil];
    }
    return self;
}

- (void)serverSwitched
{
	[self selectFolderWithId:[NSNumber numberWithInteger:-1]];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_ServerCheckPassed object:nil];
	[[NSNotificationCenter defaultCenter] removeObserver:self name:ISMSNotification_ServerSwitched object:nil];
	
	[folders release]; folders = nil;
	
	[borderColor release]; borderColor = nil;
	[textColor release]; textColor = nil;
	[lightColor release]; lightColor = nil;
	[darkColor release]; darkColor = nil;
	
	[labels release]; labels = nil;
    [super dealloc];
}

NSInteger folderSort2(id keyVal1, id keyVal2, void *context)
{
    NSString *folder1 = [(NSArray*)keyVal1 objectAtIndexSafe:1];
	NSString *folder2 = [(NSArray*)keyVal2 objectAtIndexSafe:1];
	return [folder1 caseInsensitiveCompare:folder2];
}

- (NSDictionary *)folders
{
	@synchronized(self)
	{
		return folders;
	}
}

- (void)setFolders:(NSDictionary *)namesAndIds
{
	@synchronized(self)
	{
		// Set the property
		[folders release]; folders = nil;
		folders = [namesAndIds retain];
		
		// Remove old labels
		for (UILabel *label in labels)
		{
			[label removeFromSuperview];
		}
		[labels removeAllObjects];
		
		sizeIncrease = [folders count] * 30.0f;
		
		NSMutableArray *sortedValues = [NSMutableArray arrayWithCapacity:[folders count]];
		for (NSNumber *key in [folders allKeys])
		{
			if ([key intValue] != -1)
			{
				NSArray *keyValuePair = [NSArray arrayWithObjects:key, [folders objectForKey:key], nil];
				[sortedValues addObject:keyValuePair];
			}
		}
		
		/*// Sort by folder name - iOS 4.0+ only
		 [sortedValues sortUsingComparator: ^NSComparisonResult(id keyVal1, id keyVal2) {
		 NSString *folder1 = [(NSArray*)keyVal1 objectAtIndexSafe:1];
		 NSString *folder2 = [(NSArray*)keyVal2 objectAtIndexSafe:1];
		 return [folder1 caseInsensitiveCompare:folder2];
		 }];*/
		
		// Sort by folder name
		[sortedValues sortUsingFunction:folderSort2 context:NULL];
		
		// Add All Folders again
		NSArray *keyValuePair = [NSArray arrayWithObjects:@"-1", @"All Folders", nil];
		[sortedValues insertObject:keyValuePair atIndex:0];
		
		//DLog(@"keys: %@", [folders allKeys]);
		//NSMutableArray *keys = [NSMutableArray arrayWithArray:[[folders allKeys] sortedArrayUsingSelector:@selector(compare:)]];
		//DLog(@"sorted keys: %@", keys);
		
		// Process the names and create the labels/buttons
		for (int i = 0; i < [sortedValues count]; i++)
		{
			NSString *folder   = [[sortedValues objectAtIndexSafe:i] objectAtIndexSafe:1];
			NSUInteger tag     = [[[sortedValues objectAtIndexSafe:i] objectAtIndexSafe:0] intValue];
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
			folderLabel.tag = tag;
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
}

- (void)toggleDropdown:(id)sender
{
	if (!isOpen)
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.25];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(viewsFinishedMoving)];
		self.height += sizeIncrease;
		[delegate folderDropdownMoveViewsY:sizeIncrease];
		[UIView commitAnimations];
		
		[CATransaction begin];
		[CATransaction setAnimationDuration:.25];
		arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * -60.0f, 0.0f, 0.0f, 1.0f);
		[CATransaction commit];
	}
	else
	{
		[UIView beginAnimations:nil context:NULL];
		[UIView setAnimationDuration:.25];
		[UIView setAnimationDelegate:self];
		[UIView setAnimationDidStopSelector:@selector(viewsFinishedMoving)];
		self.height -= sizeIncrease;
		[delegate folderDropdownMoveViewsY:-sizeIncrease];
		[UIView commitAnimations];
		
		[CATransaction begin];
		[CATransaction setAnimationDuration:.25];
		arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
		[CATransaction commit];
	}
	
	isOpen = !isOpen;
}

- (void)viewsFinishedMoving
{
	[delegate folderDropdownViewsFinishedMoving];
}

- (void)closeDropdown
{
	if (isOpen)
	{
		[self toggleDropdown:nil];
	}
}

- (void)closeDropdownFast
{
	if (isOpen)
	{
		isOpen = NO;
		
		self.height -= sizeIncrease;
		[delegate folderDropdownMoveViewsY:-sizeIncrease];
		
		arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
	}
}

- (void)selectFolder:(id)sender
{
	UIButton *button = (UIButton *)sender;
	UILabel  *label  = (UILabel *)button.superview;
	
	//DLog(@"Folder selected: %@ -- %i", label.text, label.tag);
	
	self.selectedFolderId = [NSNumber numberWithInt:label.tag];
	NSLog(@"%@", [folders objectForKey:selectedFolderId]);
	selectedFolderLabel.text = [folders objectForKey:selectedFolderId];
	//[self toggleDropdown:nil];
	[self closeDropdownFast];
	
	// Call the delegate method
	[delegate folderDropdownSelectFolder:selectedFolderId];	
}

- (void)selectFolderWithId:(NSNumber *)folderId
{
	self.selectedFolderId = folderId;
	selectedFolderLabel.text = [folders objectForKey:selectedFolderId];
}

- (void)updateFolders
{    
	if (connection)
	{
		[connection cancel]; 
		[connection release]; connection = nil;
	}
	
	//DLog(@"Folder dropdown: updating folders");
    NSMutableURLRequest *request = [NSMutableURLRequest requestWithSUSAction:@"getMusicFolders" andParameters:nil];
	//DLog(@"folder dropdown url: %@   body: %@  headers: %@", [[request URL] absoluteString], [[[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding] autorelease], [request allHTTPHeaderFields]);
    
	connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		receivedData = [[NSMutableData alloc] initWithCapacity:0];
	} 
	else 
	{		
		// Inform the user that the connection failed.
		NSString *message = [NSString stringWithFormat:@"There was an error loading the music folders for the dropdown."];
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
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
	[alert show];
	[alert release];
	
	[connection release]; connection = nil;
	[receivedData release];
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	//DLog(@"folder dropdown connection finished: %@", [[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding] autorelease]);
	
	NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:receivedData];
	[xmlParser setDelegate:self];
	[xmlParser parse];
	[xmlParser release];
	
	[connection release]; connection = nil;
	[receivedData release];
}

#pragma XMLParser delegate

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
	DLog(@"Error parsing update XML response");
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if([elementName isEqualToString:@"musicFolders"])
	{
		updatedfolders = [[NSMutableDictionary alloc] init];
		
		[updatedfolders setObject:@"All Folders" forKey:[NSNumber numberWithInt:-1]];
	}
	else if ([elementName isEqualToString:@"musicFolder"])
	{
		NSNumber *folderId = [NSNumber numberWithInt:[[attributeDict objectForKey:@"id"] intValue]];
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
		[SUSRootFoldersDAO setFolderDropdownFolders:self.folders];
		
		[updatedfolders release];
	}
}

@end
