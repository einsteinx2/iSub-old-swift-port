//
//  FolderDropdownControl.m
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "FolderDropdownControl.h"
#import <QuartzCore/QuartzCore.h>

@interface FolderDropdownControl ()
{
    __strong NSDictionary *_folders;
}
@end

@implementation FolderDropdownControl

- (id)initWithFrame:(CGRect)frame 
{
    self = [super initWithFrame:frame];
    if (self) 
	{
		_selectedFolderId = [NSNumber numberWithInt:-1];
		_folders = [SUSRootFoldersDAO folderDropdownFolders];
		_labels = [[NSMutableArray alloc] init];
		_isOpen = NO;
		_borderColor = [[UIColor alloc] initWithRed:156.0/255.0 green:161.0/255.0 blue:168.0/255.0 alpha:1];
		_textColor   = [[UIColor alloc] initWithRed:106.0/255.0 green:111.0/255.0 blue:118.0/255.0 alpha:1];
		_lightColor  = [[UIColor alloc] initWithRed:206.0/255.0 green:211.0/255.0 blue:218.0/255.0 alpha:1];
		_darkColor   = [[UIColor alloc] initWithRed:196.0/255.0 green:201.0/255.0 blue:208.0/255.0 alpha:1];
		
		self.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		self.userInteractionEnabled = YES;
		self.backgroundColor = [UIColor clearColor];
		self.layer.borderColor = _borderColor.CGColor;
		self.layer.borderWidth = 2.0;
		self.layer.cornerRadius = 8;
		self.layer.masksToBounds = YES;
		
		_selectedFolderLabel = [[UILabel alloc] initWithFrame:CGRectMake(5, 0, self.frame.size.width - 10, 30)];
		_selectedFolderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		_selectedFolderLabel.userInteractionEnabled = YES;
		_selectedFolderLabel.backgroundColor = [UIColor clearColor];
		_selectedFolderLabel.textColor = _borderColor;
		_selectedFolderLabel.textAlignment = UITextAlignmentCenter;
		_selectedFolderLabel.font = [UIFont boldSystemFontOfSize:20];
		_selectedFolderLabel.text = @"All Folders";
		[self addSubview:_selectedFolderLabel];
		
		UIView *arrowImageView = [[UIView alloc] initWithFrame:CGRectMake(193, 7, 18, 18)];
		arrowImageView.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
		[self addSubview:arrowImageView];
		
		_arrowImage = [[CALayer alloc] init];
		_arrowImage.frame = CGRectMake(0, 0, 18, 18);
		_arrowImage.contentsGravity = kCAGravityResizeAspect;
		_arrowImage.contents = (id)[UIImage imageNamed:@"folder-dropdown-arrow.png"].CGImage;
		[[arrowImageView layer] addSublayer:_arrowImage];
		
		UIButton *dropdownButton = [[UIButton alloc] initWithFrame:CGRectMake(0, 0, 220, 30)];
		dropdownButton.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		[dropdownButton addTarget:self action:@selector(toggleDropdown:) forControlEvents:UIControlEventTouchUpInside];
		[self addSubview:dropdownButton];
		
		[self updateFolders];
		
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(updateFolders) name:ISMSNotification_ServerCheckPassed object:nil];
		//[[NSNotificationCenter defaultCenter] addObserver:self selector:@selector(serverSwitched) name:ISMSNotification_ServerSwitched object:nil];
    }
    return self;
}

/*- (void)serverSwitched
{
	[self selectFolderWithId:[NSNumber numberWithInteger:-1]];
}

- (void)dealloc
{
	[[NSNotificationCenter defaultCenter] removeObserver:self];	
}*/

NSInteger folderSort2(id keyVal1, id keyVal2, void *context)
{
    NSString *folder1 = [(NSArray*)keyVal1 objectAtIndexSafe:1];
	NSString *folder2 = [(NSArray*)keyVal2 objectAtIndexSafe:1];
	return [folder1 caseInsensitiveCompare:folder2];
}

- (NSDictionary *)folders
{
	return _folders;
}

- (void)setFolders:(NSDictionary *)namesAndIds
{
	// Set the property
	_folders = namesAndIds;
	
	// Remove old labels
	for (UILabel *label in self.labels)
	{
		[label removeFromSuperview];
	}
	[self.labels removeAllObjects];
	
	self.sizeIncrease = _folders.count * 30.0f;
	
	NSMutableArray *sortedValues = [NSMutableArray arrayWithCapacity:_folders.count];
	for (NSNumber *key in _folders.allKeys)
	{
		if ([key intValue] != -1)
		{
			NSArray *keyValuePair = [NSArray arrayWithObjects:key, [_folders objectForKey:key], nil];
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
		CGRect buttonFrame = CGRectMake(0, 0, labelFrame.size.width, labelFrame.size.height);
		
		UILabel *folderLabel = [[UILabel alloc] initWithFrame:labelFrame];
		folderLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
		folderLabel.userInteractionEnabled = YES;
		//folderLabel.alpha = 0.0;
		if (i % 2 == 0)
			folderLabel.backgroundColor = self.lightColor;
		else
			folderLabel.backgroundColor = self.darkColor;
		folderLabel.textColor = self.textColor;
		folderLabel.textAlignment = UITextAlignmentCenter;
		folderLabel.font = [UIFont boldSystemFontOfSize:20];
		folderLabel.text = folder;
		folderLabel.tag = tag;
		[self addSubview:folderLabel];
		[self.labels addObject:folderLabel];
		
		UIButton *folderButton = [UIButton buttonWithType:UIButtonTypeCustom];
		folderButton.frame = buttonFrame;
		folderButton.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleHeight;
		[folderButton addTarget:self action:@selector(selectFolder:) forControlEvents:UIControlEventTouchUpInside];
		[folderLabel addSubview:folderButton];
	}
}

- (void)toggleDropdown:(id)sender
{
	if (!self.isOpen)
	{
		[UIView animateWithDuration:.25 animations:^
		{
			self.height += self.sizeIncrease;
			[self.delegate folderDropdownMoveViewsY:self.sizeIncrease];
		} 
		completion:^(BOOL finished)
		{
			[self.delegate folderDropdownViewsFinishedMoving];
		}];
				
		[CATransaction begin];
		[CATransaction setAnimationDuration:.25];
		self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * -60.0f, 0.0f, 0.0f, 1.0f);
		[CATransaction commit];
	}
	else
	{
		[UIView animateWithDuration:.25 animations:^
		{
			self.height -= self.sizeIncrease;
			[self.delegate folderDropdownMoveViewsY:-self.sizeIncrease];
		}
		completion:^(BOOL finished)
		{
			[self.delegate folderDropdownViewsFinishedMoving];
		}];
		
		[CATransaction begin];
		[CATransaction setAnimationDuration:.25];
		self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
		[CATransaction commit];
	}
	
	self.isOpen = !self.isOpen;
}

- (void)closeDropdown
{
	if (self.isOpen)
	{
		[self toggleDropdown:nil];
	}
}

- (void)closeDropdownFast
{
	if (self.isOpen)
	{
		self.isOpen = NO;
		
		self.height -= self.sizeIncrease;
		[self.delegate folderDropdownMoveViewsY:-self.sizeIncrease];
		
		self.arrowImage.transform = CATransform3DMakeRotation((M_PI / 180.0) * 0.0f, 0.0f, 0.0f, 1.0f);
		
		[self.delegate folderDropdownViewsFinishedMoving];
	}
}

- (void)selectFolder:(id)sender
{
	UIButton *button = (UIButton *)sender;
	UILabel  *label  = (UILabel *)button.superview;
	
	//DLog(@"Folder selected: %@ -- %i", label.text, label.tag);
	
	self.selectedFolderId = [NSNumber numberWithInt:label.tag];
	self.selectedFolderLabel.text = [self.folders objectForKey:self.selectedFolderId];
	//[self toggleDropdown:nil];
	[self closeDropdownFast];
	
	// Call the delegate method
	[self.delegate folderDropdownSelectFolder:self.selectedFolderId];	
}

- (void)selectFolderWithId:(NSNumber *)folderId
{
	self.selectedFolderId = folderId;
	self.selectedFolderLabel.text = [self.folders objectForKey:self.selectedFolderId];
}

- (void)updateFolders
{    
	[self.connection cancel];
	self.connection = nil;
	
	//DLog(@"Folder dropdown: updating folders");
    NSMutableURLRequest *request;
    
    if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
        request = [NSMutableURLRequest requestWithSUSAction:@"getMusicFolders" parameters:nil];
	}
    else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
        NSDictionary *parameters = [NSDictionary dictionaryWithObject:@"true" forKey:@"mediaFolders"];
        request = [NSMutableURLRequest requestWithPMSAction:@"folders" parameters:parameters];
    }
    //DLog(@"folder dropdown url: %@   body: %@  headers: %@", [[request URL] absoluteString], [[[NSString alloc] initWithData:[request HTTPBody] encoding:NSUTF8StringEncoding] autorelease], [request allHTTPHeaderFields]);
    
	self.connection = [[NSURLConnection alloc] initWithRequest:request delegate:self];
	if (self.connection)
	{
		// Create the NSMutableData to hold the received data.
		// receivedData is an instance variable declared elsewhere.
		self.receivedData = [[NSMutableData alloc] initWithCapacity:0];
	} 
	else 
	{		
		// Inform the user that the connection failed.
		NSString *message = [NSString stringWithFormat:@"There was an error loading the music folders for the dropdown."];
		CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
		[alert show];
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
	[self.receivedData setLength:0];
}

- (void)connection:(NSURLConnection *)theConnection didReceiveData:(NSData *)incrementalData 
{
    [self.receivedData appendData:incrementalData];
}

- (void)connection:(NSURLConnection *)theConnection didFailWithError:(NSError *)error
{
	// Inform the user that the connection failed.
	NSString *message = [NSString stringWithFormat:@"There was an error loading the music folders for the dropdown.\n\nError %i: %@", [error code], [error localizedDescription]];
	CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:message delegate:nil cancelButtonTitle:@"OK" otherButtonTitles:nil];
	[alert show];
	
	self.receivedData = nil;
	self.connection = nil;
}	

- (void)connectionDidFinishLoading:(NSURLConnection *)theConnection 
{	
	//DLog(@"folder dropdown connection finished: %@", [[[NSString alloc] initWithData:receivedData encoding:NSUTF8StringEncoding] autorelease]);
	
	if ([settingsS.serverType isEqualToString:SUBSONIC] || [settingsS.serverType isEqualToString:UBUNTU_ONE])
	{
		NSXMLParser *xmlParser = [[NSXMLParser alloc] initWithData:self.receivedData];
		[xmlParser setDelegate:self];
		[xmlParser parse];
	}
	else if ([settingsS.serverType isEqualToString:WAVEBOX])
	{
		self.updatedfolders = [[NSMutableDictionary alloc] init];
		[self.updatedfolders setObject:@"All Folders" forKey:[NSNumber numberWithInt:-1]];
		
		
		NSString *responseString = [[NSString alloc] initWithData:self.receivedData encoding:NSUTF8StringEncoding];
        DLog(@"folder dropdown: %@", responseString);
		NSDictionary *response = [responseString JSONValue];
		
		NSArray *responseFolders = [response objectForKey:@"folders"];
		for (NSDictionary *folder in responseFolders)
		{
			NSNumber *folderId = [NSNumber numberWithInt:[[folder objectForKey:@"folderId"] intValue]];
			NSString *folderName = [folder objectForKey:@"folderName"];
			
			[self.updatedfolders setObject:folderName forKey:folderId];
		}
        
        self.folders = [NSDictionary dictionaryWithDictionary:self.updatedfolders];
		
		// Save the default
		[SUSRootFoldersDAO setFolderDropdownFolders:self.folders];
	}
	
	self.receivedData = nil;
	self.connection = nil;
}

#pragma XMLParser delegate

- (void)parser:(NSXMLParser *)parser parseErrorOccurred:(NSError *)parseError
{
//DLog(@"Error parsing update XML response");
}

- (void)parser:(NSXMLParser *)parser didStartElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qualifiedName 
	attributes:(NSDictionary *)attributeDict 
{
	if([elementName isEqualToString:@"musicFolders"])
	{
		self.updatedfolders = [[NSMutableDictionary alloc] init];
		
		[self.updatedfolders setObject:@"All Folders" forKey:[NSNumber numberWithInt:-1]];
	}
	else if ([elementName isEqualToString:@"musicFolder"])
	{
		NSNumber *folderId = [NSNumber numberWithInt:[[attributeDict objectForKey:@"id"] intValue]];
		NSString *folderName = [attributeDict objectForKey:@"name"];
		
		[self.updatedfolders setObject:folderName forKey:folderId];
	}
}

- (void)parser:(NSXMLParser *)parser didEndElement:(NSString *)elementName 
  namespaceURI:(NSString *)namespaceURI qualifiedName:(NSString *)qName
{
	if([elementName isEqualToString:@"musicFolders"])
	{
		self.folders = [NSDictionary dictionaryWithDictionary:self.updatedfolders];
		
		// Save the default
		[SUSRootFoldersDAO setFolderDropdownFolders:self.folders];
		
	}
}

@end
