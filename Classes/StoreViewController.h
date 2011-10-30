//
//  StoreViewController.h
//  iSub
//
//  Created by Ben Baron on 12/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "MKStoreManager.h"

@class iSubAppDelegate, ViewObjectsSingleton;

@interface StoreViewController : UITableViewController
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MKStoreManager *storeManager;
	
	NSArray *storeItems;
		
	NSTimer *checkProductsTimer;
}

@property (nonatomic, retain) NSArray *storeItems;

- (void)checkProducts;
- (void)organizeList;

@end
