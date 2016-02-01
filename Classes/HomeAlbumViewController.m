//
//  HomeAlbumViewController.m
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "HomeAlbumViewController.h"
#import "Imports.h"
#import "iPhoneStreamingPlayerViewController.h"
#import "ServerListViewController.h"
#import "UIViewController+PushViewControllerCustom.h"
#import "iSub-Swift.h"

@interface HomeAlbumViewController() <ItemUITableViewCellDelegate>
@end

@implementation HomeAlbumViewController

- (id)initWithNibName:(NSString *)n bundle:(NSBundle *)b;
{
    self = [super initWithNibName:n bundle:b];
	
    if (self != nil)
    {
		_isMoreAlbums = YES;
    }
	
    return self;
}

- (void)viewDidLoad  
{	
	[super viewDidLoad];
	
	if (!self.tableView.tableHeaderView) self.tableView.tableHeaderView = [[UIView alloc] init];	
}

- (void)customizeTableView:(UITableView *)tableView
{
    tableView.rowHeight = ISMSNormalize(ISMSAlbumCellHeight);
}

- (void)didReceiveMemoryWarning 
{
	// Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}


- (void)loadMoreResults
{	
	if (self.isLoading)
		return;
	
	self.isLoading = YES;
	self.offset += 20;
    
    self.loader = [[ISMSQuickAlbumsLoader alloc] initWithDelegate:self];
    self.loader.modifier = self.modifier;
    self.loader.offset = self.offset;
    [self.loader startLoad];
}

- (void)loadingFailed:(ISMSLoader *)theLoader withError:(NSError *)error
{
    self.loader = nil;
	self.isLoading = NO;
	    
    CustomUIAlertView *alert = [[CustomUIAlertView alloc] initWithTitle:@"Error" message:[NSString stringWithFormat:@"There was an error doing the search.\n\nError:%@", error.localizedDescription] delegate:self cancelButtonTitle:@"OK" otherButtonTitles:nil];
    [alert show];
}	

- (void)loadingFinished:(ISMSLoader *)theLoader
{
    if (self.loader.listOfAlbums.count == 0)
    {
        // There are no more songs
		self.isMoreAlbums = NO;
    }
    else 
    {
        // Add the new results to the list of songs
        [self.listOfAlbums addObjectsFromArray:self.loader.listOfAlbums];
    }
    
    // Reload the table
    [self.tableView reloadData];
    self.isLoading = NO;
    
	self.loader = nil;
}

#pragma mark Table view methods

// Customize the number of rows in the table view.
- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section 
{
	return self.listOfAlbums.count + 1;
}


// Customize the appearance of table view cells.
- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath 
{		
	if (indexPath.row < self.listOfAlbums.count)
	{
		static NSString *cellIdentifier = @"AllAlbumsCell";
		ItemUITableViewCell *cell = [tableView dequeueReusableCellWithIdentifier:cellIdentifier];
		if (!cell)
		{
			cell = [[ItemUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
            cell.alwaysShowCoverArt = YES;
            cell.delegate = self;
		}
		cell.accessoryType = UITableViewCellAccessoryDisclosureIndicator;
		
		ISMSAlbum *anAlbum = [self.listOfAlbums objectAtIndexSafe:indexPath.row];
		cell.associatedObject = anAlbum;
		
		cell.coverArtId = anAlbum.coverArtId;
		
        cell.title = anAlbum.name;
        cell.subTitle = anAlbum.artistName;
		
		// Setup cell backgrond color
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		
		return cell;
	}
	else if (indexPath.row == self.listOfAlbums.count)
	{
		// This is the last cell and there could be more results, load the next 20 songs;
		static NSString *cellIdentifier = @"HomeAlbumLoadCell";
		UITableViewCell *cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];

		// Set background color
		cell.backgroundView = [viewObjectsS createCellBackground:indexPath.row];
		cell.textLabel.backgroundColor = cell.backgroundView.backgroundColor;
		
		if (self.isMoreAlbums)
		{
			cell.textLabel.text = @"Loading more results...";
			UIActivityIndicatorView *indicator = [[UIActivityIndicatorView alloc] initWithActivityIndicatorStyle:UIActivityIndicatorViewStyleGray];
			indicator.center = CGPointMake(300, 30);
			[cell addSubview:indicator];
			[indicator startAnimating];
			
			[self loadMoreResults];
		}
		else 
		{
			cell.textLabel.text = @"No more results";
		}
		
		return cell;
	}
	
	// In case somehow no cell is created, return an empty cell
	static NSString *cellIdentifier = @"EmptyCell";
	return [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath
{	
	if (!indexPath)
		return;
	
	if (viewObjectsS.isCellEnabled && indexPath.row != self.listOfAlbums.count)
	{
		ISMSAlbum *anAlbum = [self.listOfAlbums objectAtIndexSafe:indexPath.row];
		FolderViewController *albumViewController = [[FolderViewController alloc] initWithAlbum:anAlbum];
		[self pushViewControllerCustom:albumViewController];
		//[self.navigationController pushViewController:albumViewController animated:YES];
	}
	else
	{
		[self.tableView deselectRowAtIndexPath:indexPath animated:NO];
	}
}

#pragma mark - ItemUITableViewCell Delegate -

- (void)tableCellDownloadButtonPressed:(ItemUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSAlbum class]])
    {
        ISMSAlbum *album = associatedObject;
        ISMSArtist *artist = [ISMSArtist artistWithName:album.artistName andArtistId:album.artistId];
        
        [databaseS downloadAllSongs:album.albumId.stringValue artist:artist];
    }
    
    [cell.overlayView disableDownloadButton];
}

- (void)tableCellQueueButtonPressed:(ItemUITableViewCell *)cell
{
    id associatedObject = cell.associatedObject;
    if ([associatedObject isKindOfClass:[ISMSAlbum class]])
    {
        ISMSAlbum *album = associatedObject;
        ISMSArtist *artist = [ISMSArtist artistWithName:album.artistName andArtistId:album.artistId];
        
        [databaseS queueAllSongs:album.albumId.stringValue artist:artist];
    }
    
    [NSNotificationCenter postNotificationToMainThreadWithName:ISMSNotification_CurrentPlaylistSongsQueued];
}

@end

