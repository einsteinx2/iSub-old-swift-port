//
//  JukeboxXMLParser.h
//  iSub
//
//  Created by bbaron on 11/5/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class iSubAppDelegate, ViewObjectsSingleton, DatabaseSingleton;

@interface JukeboxXMLParser : NSObject <NSXMLParserDelegate>
{	
	iSubAppDelegate *appDelegate; 
	/*DatabaseControlsSingleton *databaseControls;
	ViewObjectsSingleton *viewObjects;*/

	NSUInteger currentIndex;
	BOOL isPlaying;
	float gain;
	
	NSMutableArray *listOfSongs;
}

@property NSUInteger currentIndex;
@property BOOL isPlaying;
@property float gain;

@property (nonatomic, retain) NSMutableArray *listOfSongs;

- (id) initXMLParser;

@end