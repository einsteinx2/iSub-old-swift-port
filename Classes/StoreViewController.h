//
//  StoreViewController.h
//  iSub
//
//  Created by Ben Baron on 12/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MKStoreManager.h"

@interface StoreViewController : UITableViewController
{
	MKStoreManager *storeManager;
	
	NSArray *storeItems;
		
	NSTimer *checkProductsTimer;
}

@property (retain) NSArray *storeItems;

- (void)checkProducts;
- (void)organizeList;

- (void)cancelLoad;

@end
