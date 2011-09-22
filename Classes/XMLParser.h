//
//  XMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

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

@property (nonatomic, retain) NSString *parseState;
@property (nonatomic, retain) NSString *myId;
@property (nonatomic, retain) Artist *myArtist;

@property (nonatomic, retain) NSMutableArray *indexes;
@property (nonatomic, retain) NSMutableArray *listOfArtists;
@property (nonatomic, retain) NSMutableArray *listOfAlbums;
@property (nonatomic, retain) NSMutableArray *listOfSongs;

- (id) initXMLParser;

- (void) updateMessage;

@end
