//
//  SearchXMLParser.h
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//


@interface SearchXMLParser : NSObject <NSXMLParserDelegate>

@property (retain) NSMutableArray *listOfArtists;
@property (retain) NSMutableArray *listOfAlbums;
@property (retain) NSMutableArray *listOfSongs;

- (SearchXMLParser *) initXMLParser;

@end
