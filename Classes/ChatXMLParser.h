//
//  ChatXMLParser.h
//  XML
//
//  Created by iPhone SDK Articles on 11/23/08.
//  Copyright 2008 www.iPhoneSDKArticles.com.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class iSubAppDelegate, ViewObjectsSingleton;

@interface ChatXMLParser : NSObject <NSXMLParserDelegate>
{	
	iSubAppDelegate *appDelegate; 
	ViewObjectsSingleton *viewObjects;
}

- (ChatXMLParser *) initXMLParser;

@end
