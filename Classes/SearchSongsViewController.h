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


@class iSubAppDelegate, MusicSingleton, DatabaseSingleton, ViewObjectsSingleton;

@interface SearchSongsViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	ViewObjectsSingleton *viewObjects;
	
	NSString *query;
	NSUInteger searchType;
	
	NSMutableArray *listOfArtists;
	NSMutableArray *listOfAlbums;
	NSMutableArray *listOfSongs;
	
	NSUInteger offset;
	BOOL isMoreResults;
	BOOL isLoading;
	
	NSMutableData *receivedData;
	
	NSURLConnection *connection;
}

@property (retain) NSString *query;
@property NSUInteger searchType;

@property (retain) NSMutableArray *listOfArtists;
@property (retain) NSMutableArray *listOfAlbums;
@property (retain) NSMutableArray *listOfSongs;

@property NSUInteger offset;
@property BOOL isMoreResults;

@property (retain) NSURLConnection *connection;

@end
