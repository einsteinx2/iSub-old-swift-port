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
@property (retain) NSURLConnection *connection;
@property (retain) NSMutableData *receivedData;
@property (retain) NSString *modifier;

@property (retain) IBOutlet UIButton *randomButton;
@property (retain) IBOutlet UIButton *frequentButton;
@property (retain) IBOutlet UIButton *newestButton;
@property (retain) IBOutlet UIButton *recentButton;
@property (retain) IBOutlet UIButton *cancelButton;


- (IBAction)random;
- (IBAction)frequent;
- (IBAction)newest;
- (IBAction)recent;
- (IBAction)cancel;

- (void)cancelLoad;

@end
