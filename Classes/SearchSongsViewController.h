//
//  SearchSongsViewController.h
//  iSub
//
//  Created by bbaron on 10/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//
//  ---------------
//	searchType:
//
//	0 = artist
//	1 = album
//	2 = song
//

@interface SearchSongsViewController : UITableViewController 
{
	NSMutableData *receivedData;	
}

@property (copy) NSString *query;
@property NSUInteger searchType;

@property (strong) NSMutableArray *listOfArtists;
@property (strong) NSMutableArray *listOfAlbums;
@property (strong) NSMutableArray *listOfSongs;

@property NSUInteger offset;
@property BOOL isMoreResults;

@property BOOL isLoading;

@property (strong) NSURLConnection *connection;

@end
