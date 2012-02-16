//
//  XMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//


@class iSubAppDelegate, ViewObjectsSingleton, DatabaseSingleton, Index, Artist, Album, Song;

@interface XMLParser : NSObject <NSXMLParserDelegate> 
{

	NSMutableString *currentElementValue;
	
	iSubAppDelegate *appDelegate; 
	DatabaseSingleton *databaseControls;
	Index *anIndex;
	NSMutableArray *shortcuts;
	BOOL isFirstIndex;
	
	NSString *parseState;
	NSString *myId;
	Artist *myArtist;
	
	NSMutableArray *indexes;
	NSMutableArray *listOfArtists;
	NSMutableArray *listOfAlbums;
	NSMutableArray *listOfSongs;
	
	NSMutableArray *artistsArray;
	
	ViewObjectsSingleton *viewObjects;
	
	NSMutableArray *loadedSongMD5s;
}

@property (retain) NSString *parseState;
@property (retain) NSString *myId;
@property (retain) Artist *myArtist;

@property (retain) NSMutableArray *indexes;
@property (retain) NSMutableArray *listOfArtists;
@property (retain) NSMutableArray *listOfAlbums;
@property (retain) NSMutableArray *listOfSongs;

- (id) initXMLParser;

@end
