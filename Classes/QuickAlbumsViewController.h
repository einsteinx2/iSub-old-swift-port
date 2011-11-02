//
//  QuickAlbumsViewController.h
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@class iSubAppDelegate, ViewObjectsSingleton;

@interface QuickAlbumsViewController : UIViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	
	UIViewController *parent;
	
	NSDictionary *titles;
}

@property (nonatomic, assign) UIViewController *parent;

@property (nonatomic, retain) NSMutableData *receivedData;

@property (nonatomic, retain) NSString *modifier;

- (IBAction)random;
- (IBAction)frequent;
- (IBAction)newest;
- (IBAction)recent;
- (IBAction)cancel;

@end
