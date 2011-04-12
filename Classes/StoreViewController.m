//
//  StoreViewController.m
//  iSub
//
//  Created by Ben Baron on 12/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "StoreViewController.h"
#import "MKStoreManager.h"
#import "iSubAppDelegate.h"
#import "ViewObjectsSingleton.h"
#import "StoreUITableViewCell.h"

@implementation StoreViewController

@synthesize storeItems;

#pragma mark -
#pragma mark View lifecycle

-(BOOL) shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)inOrientation 
{
	if ([[[iSubAppDelegate sharedInstance].settingsDictionary objectForKey:@"lockRotationSetting"] isEqualToString:@"YES"] 
		&& inOrientation != UIInterfaceOrientationPortrait)
		return NO;
	
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.tableView reloadData];
}

- (void)viewDidLoad 
{
    [super viewDidLoad];

	appDelegate = (iSubAppDelegate*)[UIApplication sharedApplication].delegate;
	viewObjects = [ViewObjectsSingleton sharedInstance];
	storeManager = [MKStoreManager sharedManager];

    // Uncomment the following line to display an Edit button in the navigation bar for this view controller.
    // self.navigationItem.rightBarButtonItem = self.editButtonItem;
	
	/*NSDictionary *playlistFeature = [NSDictionary dictionaryWithObjectsAndKeys:@"Unlock Playlists Feature", @"title",
									@"Unlock that ability to view, edit, save, and delete playlists, stored both on the device and on the Subsonic server.", @"description",
									 [NSNumber numberWithFloat:1.99], @"price", nil];
	
	NSDictionary *cacheFeature = [NSDictionary dictionaryWithObjectsAndKeys:@"Unlock Song Cache Feature", @"title",
									 @"Unlock the ability to save songs locally to your device for playback anytime, even with no Internet access! Also automatically caches the current and next song as you listen for the best playback experience.", @"description",
									 [NSNumber numberWithFloat:1.99], @"price", nil];
	
	NSDictionary *jukeboxFeature = [NSDictionary dictionaryWithObjectsAndKeys:@"Unlock Jukebox Feature", @"title",
									 @"Unlock the ability to control your Subsonic server using iSub as a remote control. Songs that are selected will be played from the speakers connected to the computer with Subsonic installed. Now Subsonic and iSub can be the center of the party!", @"description",
									 [NSNumber numberWithFloat:1.99], @"price", nil];
	
	NSDictionary *allFeature = [NSDictionary dictionaryWithObjectsAndKeys:@"Unlock all 3 features for the price of 2!", @"title",
									 @"Unlock the ability to view and manage playlists, to cache songs for better performance and offline listening, and to control your Subsonic server like wireless jukebox. All three features for the price of two!", @"description",
									 [NSNumber numberWithFloat:1.99], @"price", nil];
	
	storeItems = [[NSArray alloc] initWithObjects:playlistFeature, cacheFeature, jukeboxFeature, allFeature, nil];*/
	storeItems = [[NSArray alloc] initWithArray:storeManager.purchasableObjects];
	
	if ([storeItems count] == 0)
	{
		[viewObjects showLoadingScreenOnMainWindow];
		checkProductsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0 target:self selector:@selector(checkProducts) userInfo:nil repeats:YES];
		[self checkProducts];
	}
	else
	{
		[self organizeList];
		[self.tableView reloadData];
	}
}

- (void)checkProducts
{
	[storeItems release];
	storeItems = [[NSArray alloc] initWithArray:storeManager.purchasableObjects];
	
	if ([storeItems count] > 0)
	{
		[checkProductsTimer invalidate];
		
		[viewObjects hideLoadingScreen];
		
		[self organizeList];
		
		[self.tableView reloadData];
	}
}

- (void)organizeList
{
	NSMutableArray *sorted = [[NSMutableArray alloc] init];
	NSMutableArray *temp = [[NSMutableArray alloc] init];
	
	for (SKProduct *product in storeItems)
	{
		if ([MKStoreManager isFeaturePurchased:[product productIdentifier]])
		{
			[temp addObject:product];
		}
		else
		{
			[sorted addObject:product];
		}
	}
	
	[sorted addObjectsFromArray:temp];
	
	[storeItems release];
	storeItems = [[NSArray alloc] initWithArray:sorted];
}


/*
- (void)viewWillAppear:(BOOL)animated {
    [super viewWillAppear:animated];
}
*/
/*
- (void)viewDidAppear:(BOOL)animated {
    [super viewDidAppear:animated];
}
*/
/*
- (void)viewWillDisappear:(BOOL)animated {
    [super viewWillDisappear:animated];
}
*/
/*
- (void)viewDidDisappear:(BOOL)animated {
    [super viewDidDisappear:animated];
}
*/
/*
// Override to allow orientations other than the default portrait orientation.
- (BOOL)shouldAutorotateToInterfaceOrientation:(UIInterfaceOrientation)interfaceOrientation {
    // Return YES for supported orientations.
    return (interfaceOrientation == UIInterfaceOrientationPortrait);
}
*/


#pragma mark -
#pragma mark Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
	return 150.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    // Return the number of sections.
    return 1;
}


- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    // Return the number of rows in the section.
    return [storeItems count];
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
    /*static NSString *CellIdentifier = @"Cell";
    
    UITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:CellIdentifier];
    if (cell == nil) {
        cell = [[[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
    }
    
	//cell.textLabel.text = [[storeItems objectAtIndex:indexPath.row] localizedTitle];
	//cell.detailTextLabel.text = [[[storeItems objectAtIndex:indexPath.row] price] stringValue];
	
	UILabel *titleLabel = [[UILabel alloc] init]; //WithFrame:CGRectMake(10, 10, 270, 20)];
	titleLabel.frame = CGRectMake(10, 10, 270, 20);
	titleLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth | UIViewAutoresizingFlexibleRightMargin;
	titleLabel.font = [UIFont boldSystemFontOfSize:20];
	titleLabel.textColor = [UIColor blackColor];
	titleLabel.textAlignment = UITextAlignmentLeft;
	titleLabel.text = [[storeItems objectAtIndex:indexPath.row] localizedTitle];
	[cell.contentView addSubview:titleLabel];
	
	UILabel *descLabel = [[UILabel alloc] init]; //WithFrame:CGRectMake(10, 40, 310, 90)];
	descLabel.frame = CGRectMake(10, 40, 310, 90);
	descLabel.autoresizingMask = UIViewAutoresizingFlexibleWidth;
	descLabel.font = [UIFont systemFontOfSize:14];
	descLabel.textColor = [UIColor grayColor];
	descLabel.textAlignment = UITextAlignmentLeft;
	descLabel.numberOfLines = 0;
	descLabel.text = [[storeItems objectAtIndex:indexPath.row] localizedDescription];
	//[descLabel sizeToFit];
	[cell.contentView addSubview:descLabel];
	
	UILabel *priceLabel = [[UILabel alloc] init]; //WithFrame:CGRectMake(260, 10, 30, 20)];
	priceLabel.frame = CGRectMake(100, 10, 30, 20);
	priceLabel.autoresizingMask = UIViewAutoresizingFlexibleLeftMargin;
	priceLabel.font = [UIFont boldSystemFontOfSize:20];
	priceLabel.textColor = [UIColor redColor];
	priceLabel.textAlignment = UITextAlignmentRight;
	priceLabel.text = [[[storeItems objectAtIndex:indexPath.row] price] stringValue];
	[cell.contentView addSubview:priceLabel];
		
    return cell;*/
	
	static NSString *CellIdentifier = @"Cell";
    
    StoreUITableViewCell *cell = [[[StoreUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:CellIdentifier] autorelease];
	
    cell.myProduct = [storeItems objectAtIndex:indexPath.row];
	
    return cell;

}


/*
// Override to support conditional editing of the table view.
- (BOOL)tableView:(UITableView *)tableView canEditRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the specified item to be editable.
    return YES;
}
*/


/*
// Override to support editing the table view.
- (void)tableView:(UITableView *)tableView commitEditingStyle:(UITableViewCellEditingStyle)editingStyle forRowAtIndexPath:(NSIndexPath *)indexPath {
    
    if (editingStyle == UITableViewCellEditingStyleDelete) {
        // Delete the row from the data source.
        [tableView deleteRowsAtIndexPaths:[NSArray arrayWithObject:indexPath] withRowAnimation:UITableViewRowAnimationFade];
    }   
    else if (editingStyle == UITableViewCellEditingStyleInsert) {
        // Create a new instance of the appropriate class, insert it into the array, and add a new row to the table view.
    }   
}
*/


/*
// Override to support rearranging the table view.
- (void)tableView:(UITableView *)tableView moveRowAtIndexPath:(NSIndexPath *)fromIndexPath toIndexPath:(NSIndexPath *)toIndexPath {
}
*/


/*
// Override to support conditional rearranging of the table view.
- (BOOL)tableView:(UITableView *)tableView canMoveRowAtIndexPath:(NSIndexPath *)indexPath {
    // Return NO if you do not want the item to be re-orderable.
    return YES;
}
*/


#pragma mark -
#pragma mark Table view delegate

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
   // bigRow = indexPath.row;
	//[tableView reloadData];
	
	if (![MKStoreManager isFeaturePurchased:[[storeItems objectAtIndex:indexPath.row] productIdentifier]])
	{
		[storeManager buyFeature:[[storeItems objectAtIndex:indexPath.row] productIdentifier]];
		
		[self.navigationController popToRootViewControllerAnimated:YES];
	}
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}


#pragma mark -
#pragma mark Memory management

- (void)didReceiveMemoryWarning {
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
    
    // Relinquish ownership any cached data, images, etc. that aren't in use.
}

- (void)viewDidUnload {
    // Relinquish ownership of anything that can be recreated in viewDidLoad or on demand.
    // For example: self.myOutlet = nil;
}


- (void)dealloc 
{
	[storeItems release];
    [super dealloc];
}


@end

