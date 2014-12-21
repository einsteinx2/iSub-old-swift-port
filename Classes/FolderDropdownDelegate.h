//
//  FolderDropdownDelegate.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//


@protocol FolderDropdownDelegate <NSObject>

@required
- (void)folderDropdownMoveViewsY:(CGFloat)y;
- (void)folderDropdownViewsFinishedMoving;
- (void)folderDropdownSelectFolder:(NSNumber *)folderId;

@end