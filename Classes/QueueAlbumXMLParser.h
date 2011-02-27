//
//  QueueAlbumXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//

#import <UIKit/UIKit.h>

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

@property (nonatomic, retain) Artist *myArtist;
@property (nonatomic, retain) NSMutableArray *listOfAlbums;
@property (nonatomic, retain) NSMutableArray *listOfSongs;

- (id) initXMLParser;

@end
