//
//  FolderDropdownControl.h
//  iSub
//
//  Created by Ben Baron on 3/19/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface FolderDropdownControl : UIView <NSXMLParserDelegate>
{
	CALayer *arrowImage;
	
	UITableView *tableView;
	NSArray *viewsToMove;
	
	float sizeIncrease;
	
	NSDictionary *folders;
	NSMutableDictionary *updatedfolders;
	NSInteger selectedFolderId;
	
	UILabel *selectedFolderLabel;
	
	NSMutableArray *labels;
	
	BOOL isOpen;
	
	// Colors
	UIColor *borderColor;
	UIColor *textColor;
	UIColor *lightColor;
	UIColor *darkColor;
	
	id delegate;
	
	NSMutableData *receivedData;
}

@property (assign) UITableView *tableView;
@property (nonatomic, retain) NSArray *viewsToMove;
@property (nonatomic, retain) NSDictionary *folders;

@property NSInteger selectedFolderId;

// Colors
@property (nonatomic, retain) UIColor *borderColor;
@property (nonatomic, retain) UIColor *textColor;
@property (nonatomic, retain) UIColor *lightColor;
@property (nonatomic, retain) UIColor *darkColor;

@property (assign) id delegate;

- (void)selectFolderWithId:(NSUInteger)folderId;
- (void)updateFolders;

@end
