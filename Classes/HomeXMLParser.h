//
//  HomeXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//


@class Index, Artist, Album, Song;

@interface HomeXMLParser : NSObject <NSXMLParserDelegate> 
{
	NSMutableString *currentElementValue;
	
	
	NSString *myId;

	NSMutableArray *listOfAlbums;
		
}

@property (retain) NSString *myId;

@property (retain) NSMutableArray *listOfAlbums;

- (HomeXMLParser *) initXMLParser;

@end
