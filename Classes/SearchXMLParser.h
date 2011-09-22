//
//  SearchXMLParser.h
//  iSub
//
//  Created by bbaron on 10/21/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class iSubAppDelegate;

@interface SearchXMLParser : NSObject <NSXMLParserDelegate>
{
	iSubAppDelegate *appDelegate;
	
	NSMutableArray *listOfArtists;
	NSMutableArray *listOfAlbums;
	NSMutableArray *listOfSongs;
}

@property (nonatomic, retain) NSMutableArray *listOfArtists;
@property (nonatomic, retain) NSMutableArray *listOfAlbums;
@property (nonatomic, retain) NSMutableArray *listOfSongs;

- (SearchXMLParser *) initXMLParser;

@end
