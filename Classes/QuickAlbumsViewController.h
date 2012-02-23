//
//  QuickAlbumsViewController.h
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface QuickAlbumsViewController : UIViewController 
{
	
	UIViewController *parent;
	
	NSDictionary *titles;
}

@property (assign) UIViewController *parent;

@property (retain) NSMutableData *receivedData;

@property (retain) NSString *modifier;

- (IBAction)random;
- (IBAction)frequent;
- (IBAction)newest;
- (IBAction)recent;
- (IBAction)cancel;

@end
