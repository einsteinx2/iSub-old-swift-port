//
//  QuickAlbumsViewController.h
//  iSub
//
//  Created by bbaron on 11/6/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface QuickAlbumsViewController : UIViewController 

@property (unsafe_unretained) UIViewController *parent;

@property (strong) NSDictionary *titles;
@property (strong) NSURLConnection *connection;
@property (strong) NSMutableData *receivedData;
@property (strong) NSString *modifier;

@property (strong) IBOutlet UIButton *randomButton;
@property (strong) IBOutlet UIButton *frequentButton;
@property (strong) IBOutlet UIButton *newestButton;
@property (strong) IBOutlet UIButton *recentButton;
@property (strong) IBOutlet UIButton *cancelButton;


- (IBAction)random;
- (IBAction)frequent;
- (IBAction)newest;
- (IBAction)recent;
- (IBAction)cancel;

- (void)cancelLoad;

@end
