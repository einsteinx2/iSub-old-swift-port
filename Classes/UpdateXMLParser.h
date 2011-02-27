//
//  UpdateXMLParser.h
//  iSub
//
//  Created by bbaron on 8/15/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class iSubAppDelegate;

@interface UpdateXMLParser : NSObject <NSXMLParserDelegate>
{
	iSubAppDelegate *appDelegate;
	
	NSString *newVersion;
	NSString *message;
}

- (id) initXMLParser;

@end
