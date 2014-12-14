//
//  StoreViewController.m
//  iSub
//
//  Created by Ben Baron on 12/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "StoreViewController.h"
#import "StoreUITableViewCell.h"

@interface StoreViewController()
{
    MKStoreManager *_storeManager;
    NSArray *_storeItems;
    NSTimer *_checkProductsTimer;
}
@end

@implementation StoreViewController

#pragma mark - Rotation -

- (BOOL)shouldAutorotate
{
    if (settingsS.isRotationLockEnabled && [UIDevice currentDevice].orientation != UIDeviceOrientationPortrait)
        return NO;
    
    return YES;
}

- (void)didRotateFromInterfaceOrientation:(UIInterfaceOrientation)fromInterfaceOrientation
{
	[self.tableView reloadData];
}

#pragma mark - Lifecycle -

- (void)viewDidLoad 
{
    [super viewDidLoad];

	_storeManager = [MKStoreManager sharedManager];

	_storeItems = _storeManager.purchasableObjects;
	
	[[NSNotificationCenter defaultCenter] addObserver:self
                                             selector:@selector(_storePurchaseComplete:)
                                                 name:ISMSNotification_StorePurchaseComplete
                                               object:nil];
	
	if (_storeItems.count == 0)
	{
		[viewObjectsS showAlbumLoadingScreen:appDelegateS.window sender:self];
		_checkProductsTimer = [NSTimer scheduledTimerWithTimeInterval:1.0
                                                               target:self
                                                             selector:@selector(a_checkProducts:)
                                                             userInfo:nil
                                                               repeats:YES];
        [self a_checkProducts:nil];
	}
	else
	{
		[self _organizeList];
		[self.tableView reloadData];
	}
}

- (void)didReceiveMemoryWarning
{
    // Releases the view if it doesn't have a superview.
    [super didReceiveMemoryWarning];
}

- (void)dealloc 
{
    [[NSNotificationCenter defaultCenter] removeObserver:self
                                                    name:ISMSNotification_StorePurchaseComplete
                                                  object:nil];
}

#pragma mark - Notifications -

- (void)_storePurchaseComplete:(NSNotification *)notification
{
    [self.tableView reloadData];
}

#pragma mark - Actions -

- (void)a_checkProducts:(id)sender
{
    _storeItems = _storeManager.purchasableObjects;
    
    if (_storeItems.count > 0)
    {
        [_checkProductsTimer invalidate];
        _checkProductsTimer = nil;
        
        [viewObjectsS hideLoadingScreen];
        
        [self _organizeList];
        
        [self.tableView reloadData];
    }
}

#pragma mark - Loading -

- (void)cancelLoad
{
	[_checkProductsTimer invalidate];
    _checkProductsTimer = nil;
    
	[viewObjectsS hideLoadingScreen];
}

- (void)_organizeList
{
    // Place purchased products at the the end of the list
	NSMutableArray *sorted = [[NSMutableArray alloc] init];
	NSMutableArray *purchased = [[NSMutableArray alloc] init];
	
	for (SKProduct *product in _storeItems)
	{
		if ([MKStoreManager isFeaturePurchased:[product productIdentifier]])
		{
			[purchased addObject:product];
		}
		else
		{
			[sorted addObject:product];
		}
	}
	
	[sorted addObjectsFromArray:purchased];
	
	_storeItems = sorted;
}

#pragma mark - Table view data source

- (CGFloat)tableView:(UITableView *)tableView heightForRowAtIndexPath:(NSIndexPath *)indexPath
{
    return indexPath.row == 0 ? 75.0 : 150.0;
}

- (NSInteger)numberOfSectionsInTableView:(UITableView *)tableView 
{
    return 1;
}

- (NSInteger)tableView:(UITableView *)tableView numberOfRowsInSection:(NSInteger)section
{
    return _storeItems.count + 1;
}

- (UITableViewCell *)tableView:(UITableView *)tableView cellForRowAtIndexPath:(NSIndexPath *)indexPath
{
	static NSString *cellIdentifier = @"NoReuse";
	
	UITableViewCell *cell = nil;
	if (indexPath.row == 0)
	{
		cell = [[UITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		cell.textLabel.text = @"Restore previous purchases";
	}
	else
	{
		NSUInteger adjustedRow = indexPath.row - 1;
		cell = [[StoreUITableViewCell alloc] initWithStyle:UITableViewCellStyleDefault reuseIdentifier:cellIdentifier];
		((StoreUITableViewCell *)cell).myProduct = [_storeItems objectAtIndexSafe:adjustedRow];
	}
	return cell;
}

- (void)tableView:(UITableView *)tableView didSelectRowAtIndexPath:(NSIndexPath *)indexPath 
{
	if (indexPath.row == 0)
	{
		[_storeManager restorePreviousTransactions];
	}
	else
	{
		NSUInteger adjustedRow = indexPath.row - 1;
        SKProduct *product = [_storeItems objectAtIndexSafe:adjustedRow];
        NSString *identifier = [product productIdentifier];
        
		if (![MKStoreManager isFeaturePurchased:identifier])
		{
			[_storeManager buyFeature:identifier];
			
			[self.navigationController popToRootViewControllerAnimated:YES];
		}
	}
	
	[tableView deselectRowAtIndexPath:indexPath animated:YES];
}

@end

