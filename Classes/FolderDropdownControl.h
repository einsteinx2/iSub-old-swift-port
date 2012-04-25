//
//  FolderDropdownControl.h
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "FolderDropdownDelegate.h"

@interface FolderDropdownControl : UIView <NSXMLParserDelegate>

@property (strong) CALayer *arrowImage;

@property CGFloat sizeIncrease;

@property (strong) NSMutableDictionary *updatedfolders;	
@property (strong) UILabel *selectedFolderLabel;

@property (strong) NSMutableData *receivedData;
@property (strong) NSURLConnection *connection;

@property (strong) NSMutableArray *labels;
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
