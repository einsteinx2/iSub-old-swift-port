//
//  LyricsXMLParser.h
//  iSub
//
//  Created by Ben Baron on 7/11/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, MusicControlsSingleton, DatabaseControlsSingleton;

@interface LyricsXMLParser : NSObject <NSXMLParserDelegate>
{
	NSMutableString *currentElementValue;
	
	iSubAppDelegate *appDelegate;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	NSString *artist;
	NSString *title;
}

@property (nonatomic, retain) NSString *artist;
@property (nonatomic, retain) NSString *title;

- (LyricsXMLParser *) initXMLParser;

@end
