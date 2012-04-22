//
//  FolderDropdownControl.h
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "FolderDropdownDelegate.h"

@interface FolderDropdownControl : UIView <NSXMLParserDelegate>
{
	CALayer *arrowImage;
	
	float sizeIncrease;
	
	NSDictionary *folders;
	NSMutableDictionary *updatedfolders;
	NSNumber *selectedFolderId;
	
	UILabel *selectedFolderLabel;
	
	NSMutableArray *labels;
	
	BOOL isOpen;
	
	// Colors
	UIColor *borderColor;
	UIColor *textColor;
	UIColor *lightColor;
	UIColor *darkColor;
	
	id<FolderDropdownDelegate> __unsafe_unretained delegate;
	
	NSMutableData *receivedData;
	NSURLConnection *connection;
}

@property (strong) NSDictionary *folders;
@property BOOL isOpen;

@property (strong) NSNumber *selectedFolderId;

// Colors
@property (strong) UIColor *borderColor;
@property (strong) UIColor *textColor;
@property (strong) UIColor *lightColor;
@property (strong) UIColor *darkColor;

@property (unsafe_unretained) id<FolderDropdownDelegate> delegate;

- (void)selectFolderWithId:(NSNumber *)folderId;
- (void)updateFolders;
- (void)closeDropdown;
- (void)closeDropdownFast;

@end
