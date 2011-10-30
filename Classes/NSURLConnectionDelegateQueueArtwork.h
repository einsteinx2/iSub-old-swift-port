//
//  NSURLConnectionDelegateQueueArtwork.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@class DatabaseSingleton, MusicSingleton;

@interface NSURLConnectionDelegateQueueArtwork : NSObject 
{
	DatabaseSingleton *databaseControls;
	MusicSingleton *musicControls;
	
	NSMutableData *receivedData;
	
	BOOL is320;
}

@property (nonatomic, retain) NSMutableData *receivedData;
@property BOOL is320;


@end
