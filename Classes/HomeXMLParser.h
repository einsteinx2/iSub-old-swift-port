//
//  HomeXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, DatabaseControlsSingleton, Index, Artist, Album, Song;

@interface HomeXMLParser : NSObject <NSXMLParserDelegate> 
{
	NSMutableString *currentElementValue;
	
	iSubAppDelegate *appDelegate; 
	DatabaseControlsSingleton *databaseControls;
	
	NSString *myId;

	NSMutableArray *listOfAlbums;
		
	ViewObjectsSingleton *viewObjects;
}

@property (nonatomic, retain) NSString *myId;

@property (nonatomic, retain) NSMutableArray *listOfAlbums;

- (HomeXMLParser *) initXMLParser;

@end
