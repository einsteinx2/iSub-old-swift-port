//
//  SearchAllViewController.h
//  iSub
//
//  Created by Ben Baron on 4/6/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>


@interface SearchAllViewController : UITableViewController 
{
	NSMutableArray *cellNames;
	
	NSArray *listOfArtists;
	NSArray *listOfAlbums;
	NSArray *listOfSongs;
}

@property (nonatomic, retain) NSMutableArray *cellNames;

@property (nonatomic, retain) NSArray *listOfArtists;
@property (nonatomic, retain) NSArray *listOfAlbums;
@property (nonatomic, retain) NSArray *listOfSongs;

@end
