//
//  SearchAllViewController.h
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//



@interface SearchAllViewController : UITableViewController 
{
	NSMutableArray *cellNames;
	
	NSArray *listOfArtists;
	NSArray *listOfAlbums;
	NSArray *listOfSongs;
	
	NSString *query;
}

@property (retain) NSMutableArray *cellNames;

@property (retain) NSArray *listOfArtists;
@property (retain) NSArray *listOfAlbums;
@property (retain) NSArray *listOfSongs;

@property (retain) NSString *query;

@end
