//
//  ShuffleFolderPickerViewController.m
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ShuffleFolderPickerViewController.h"

@implementation ShuffleFolderPickerViewController

#pragma mark - View lifecycle

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	self.mediaFolders = [ISMSMediaFolder allMediaFoldersIncludingAllFolders];
	
	[self.tableView reloadData];
}

- (void)viewWillAppear:(BOOL)animated
{
    [super viewWillAppear:animated];
}

- (void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];
}

- (void)viewWillDisappear:(BOOL)animated
{
    [super viewWillDisappear:animated];
}

- (void)viewDidDisappear:(BOOL)animated
{
    [super viewDidDisappear:animated];
}

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return self.mediaFolders.count;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *cellIdentifier = @"ShuffleFolderPickerCell";
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
    if (!cell) 
	{
        cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
    }
    
    NSString *folder = [[self.mediaFolders objectAtIndexSafe:indexPath.row] objectAtIndexSafe:1];
	NSUInteger tag = [[[self.mediaFolders objectAtIndexSafe:indexPath.row] objectAtIndexSafe:0] intValue];
	
	cell.textLabel.text = folder;
	cell.tag = tag;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger folderId = [[tableView cellForRowAtIndexPath:indexPath] tag];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:@(folderId) forKey:@"folderId"];
	
	[NSNotificationCenter postNotificationToMainThreadWithName:@"performServerShuffle" userInfo:userInfo];
	
	[self.myDialog dismiss:YES];
}

@end
