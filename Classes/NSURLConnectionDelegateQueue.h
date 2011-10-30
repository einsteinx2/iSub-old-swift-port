//
//  NSURLConnectionDelegateQueue.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@class iSubAppDelegate, MusicSingleton, DatabaseSingleton;

@interface NSURLConnectionDelegateQueue : NSObject
{
	iSubAppDelegate *appDelegate;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;	
}


@end
