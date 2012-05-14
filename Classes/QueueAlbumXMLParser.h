//
//  QueueAlbumXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//


@class Artist, Album, Song;

@interface QueueAlbumXMLParser : NSObject <NSXMLParserDelegate>

@property (strong) NSMutableString *currentElementValue;

@property (strong) Artist *myArtist;
@property (strong) NSMutableArray *listOfAlbums;
@property (strong) NSMutableArray *listOfSongs;

- (id) initXMLParser;

@end
