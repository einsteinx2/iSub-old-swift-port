//
//  QueueAlbumXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//


@class iSubAppDelegate, ViewObjectsSingleton, Artist, Album, Song;

@interface QueueAlbumXMLParser : NSObject <NSXMLParserDelegate>
{
	NSMutableString *currentElementValue;
	
	iSubAppDelegate *appDelegate; 
	ViewObjectsSingleton *viewObjects;
	
	Artist *myArtist;
	
	NSMutableArray *listOfAlbums;
	NSMutableArray *listOfSongs;
}

@property (retain) Artist *myArtist;
@property (retain) NSMutableArray *listOfAlbums;
@property (retain) NSMutableArray *listOfSongs;

- (id) initXMLParser;

@end
