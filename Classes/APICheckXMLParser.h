//
//  APICheckXMLParser.h
//  iSub
//
//  Created by Ben Baron on 12/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class iSubAppDelegate, ViewObjectsSingleton;

@interface APICheckXMLParser : NSObject <NSXMLParserDelegate>
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	
	BOOL isNewSearchAPI;
}

- (id) initXMLParser;

@end
