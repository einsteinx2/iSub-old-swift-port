//
//  LyricsXMLParser.h
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <UIKit/UIKit.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class iSubAppDelegate, MusicSingleton, DatabaseSingleton;

@interface LyricsXMLParser : NSObject <NSXMLParserDelegate>
{
	NSMutableString *currentElementValue;
	
	iSubAppDelegate *appDelegate;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;
	
	NSString *artist;
	NSString *title;
}

@property (nonatomic, retain) NSString *artist;
@property (nonatomic, retain) NSString *title;

- (LyricsXMLParser *) initXMLParser;

@end
