//
//  ShuffleFolderPickerViewController.m
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ShuffleFolderPickerViewController.h"
#import "iSubAppDelegate.h"
#import "NSString+md5.h"
#import "SUSRootFoldersDAO.h"

@implementation ShuffleFolderPickerViewController

@synthesize sortedFolders, myDialog;

- (id)initWithStyle:(UITableViewStyle)style
{
    self = [super initWithStyle:style];
    if (self) {
        // Custom initialization
    }
    return self;
}

- (void)dealloc
{
    [super dealloc];
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Release any cached data, images, etc that aren't in use.
}

#pragma mark - View lifecycle

NSInteger folderSort1(id keyVal1, id keyVal2, void *context)
{
    NSString *folder1 = [(NSArray*)keyVal1 objectAtIndex:1];
	NSString *folder2 = [(NSArray*)keyVal2 objectAtIndex:1];
	return [folder1 caseInsensitiveCompare:folder2];
}

- (void)viewDidLoad
{
    [super viewDidLoad];
	
	appDelegate = [iSubAppDelegate sharedInstance];
	
	/*NSString *key = [NSString stringWithFormat:@"folderDropdownCache%@", [appDelegate.defaultUrl md5]];
	NSData *archivedData = [appDelegate.settingsDictionary objectForKey:key];
	NSDictionary *folders = [NSKeyedUnarchiver unarchiveObjectWithData:archivedData];*/
	
	NSDictionary *folders = [SUSRootFoldersDAO folderDropdownFolders];
	
	self.sortedFolders = [NSMutableArray arrayWithCapacity:[folders count]];
	for (NSString *key in [folders allKeys])
	{
		NSArray *keyValuePair = [NSArray arrayWithObjects:key, [folders objectForKey:key], nil];
		[sortedFolders addObject:keyValuePair];
	}
	
	/*// Sort by folder name -- iOS 4.0+ only
	[sortedFolders sortUsingComparator: ^NSComparisonResult(id keyVal1, id keyVal2) {
		NSString *folder1 = [(NSArray*)keyVal1 objectAtIndex:1];
		NSString *folder2 = [(NSArray*)keyVal2 objectAtIndex:1];
		return [folder1 caseInsensitiveCompare:folder2];
	}];*/
	
	// Sort by folder name
	[sortedFolders sortUsingFunction:folderSort1 context:NULL];
	
	[self.tableView performSelectorOnMainThread:@selector(reloadData) withObject:nil waitUntilDone:YES];
}

- (void)viewDidUnload
{
    [super viewDidUnload];
    // Release any retained subviews of the main view.
    // e.g. self.myOutlet = nil;
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

- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation
{
    // Return YES for supported orientations
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}

#pragma mark - Table view data source

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView
{
    // Return the number of sections.
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
	DLog(@"[sortedFolders count]: %i", [sortedFolders count]);
    return [sortedFolders count];
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
    NSString *folder   = [[sortedFolders objectAtIndex:indexPath.row] objectAtIndex:1];
	NSUInteger tag     = [[[sortedFolders objectAtIndex:indexPath.row] objectAtIndex:0] intValue];
	
	cell.textLabel.text = folder;
	cell.tag = tag;
    
    return cell;
}

#pragma mark - Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{
	NSInteger folderId = [[tableView cellForRowAtIndexPath:indexPath] tag];
	NSDictionary *userInfo = [NSDictionary dictionaryWithObject:[NSNumber numberWithInt:folderId] forKey:@"folderId"];
	
	[[NSNotificationCenter defaultCenter] postNotificationName:@"performServerShuffle" object:nil userInfo:userInfo];
	
	[myDialog dismiss:YES];
}

@end
