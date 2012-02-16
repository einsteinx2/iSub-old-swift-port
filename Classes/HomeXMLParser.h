//
//  HomeXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//


@class iSubAppDelegate, ViewObjectsSingleton, DatabaseSingleton, Index, Artist, Album, Song;

@interface HomeXMLParser : NSObject <NSXMLParserDelegate> 
{
	NSMutableString *currentElementValue;
	
	iSubAppDelegate *appDelegate; 
	DatabaseSingleton *databaseControls;
	
	NSString *myId;

	NSMutableArray *listOfAlbums;
		
	ViewObjectsSingleton *viewObjects;
}

@property (retain) NSString *myId;

@property (retain) NSMutableArray *listOfAlbums;

- (HomeXMLParser *) initXMLParser;

@end
