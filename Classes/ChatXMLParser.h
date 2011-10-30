//
//  ChatXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//


@class iSubAppDelegate, ViewObjectsSingleton;

@interface ChatXMLParser : NSObject <NSXMLParserDelegate>
{	
	iSubAppDelegate *appDelegate; 
	ViewObjectsSingleton *viewObjects;
}

- (ChatXMLParser *) initXMLParser;

@end
