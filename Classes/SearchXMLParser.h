//
//  SearchXMLParser.h
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@class iSubAppDelegate;

@interface SearchXMLParser : NSObject <NSXMLParserDelegate>
{
	iSubAppDelegate *appDelegate;
	
	NSMutableArray *listOfArtists;
	NSMutableArray *listOfAlbums;
	NSMutableArray *listOfSongs;
}

@property (retain) NSMutableArray *listOfArtists;
@property (retain) NSMutableArray *listOfAlbums;
@property (retain) NSMutableArray *listOfSongs;

- (SearchXMLParser *) initXMLParser;

@end
