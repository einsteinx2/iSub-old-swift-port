//
//  NSURLConnectionDelegateQueueArtwork.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@class MusicSingleton;

@interface NSURLConnectionDelegateQueueArtwork : NSObject 
{
	
	NSMutableData *receivedData;
	
	BOOL is320;
}

@property (retain) NSMutableData *receivedData;
@property BOOL is320;


@end
