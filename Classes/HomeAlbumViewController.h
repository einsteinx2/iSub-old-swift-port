//
//  HomeAlbumViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class Artist, Album;

@interface HomeAlbumViewController : UITableViewController 

@property (strong) NSMutableData *receivedData;
@property (strong) NSURLConnection *connection;

@property (strong) NSMutableArray *listOfAlbums;

@property (copy) NSString *modifier;
@property NSUInteger offset;
@property BOOL isMoreAlbums;
@property BOOL isLoading;

- (void)cancelLoad;

@end
