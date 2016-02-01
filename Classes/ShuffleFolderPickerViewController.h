//
//  ShuffleFolderPickerViewController.h
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CustomUITableViewController.h"

@class FolderPickerDialog;
@interface ShuffleFolderPickerViewController : CustomUITableViewController 

@property (strong) NSArray *mediaFolders;
@property (weak) FolderPickerDialog *myDialog;

@end
