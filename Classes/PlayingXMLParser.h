//
//  PlayingXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, Song;

@interface PlayingXMLParser : NSObject <NSXMLParserDelegate>
{

	NSMutableString *currentElementValue;
	
	iSubAppDelegate *appDelegate; 
	ViewObjectsSingleton *viewObjects;
}

- (PlayingXMLParser *) initXMLParser;

@end
