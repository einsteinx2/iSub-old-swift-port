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
}

@property (copy) NSString *myId;

@property (strong) NSMutableArray *listOfAlbums;

- (HomeXMLParser *) initXMLParser;

@end
