//
//  FoldersViewController.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright Ben Baron 2010. All rights reserved.
//

#import "FolderDropdownDelegate.h"

@interface FoldersViewController : CustomUITableViewController

// Loader Delegate Methods
- (void)loadingFailed:(ISMSLoader*)theLoader withError:(NSError *)error;
- (void)loadingFinished:(ISMSLoader*)theLoader;

// FolderDropdown Delegate Methods
- (void)folderDropdownMoveViewsY:(float)y;
- (void)folderDropdownSelectFolder:(NSNumber *)folderId;

@end
