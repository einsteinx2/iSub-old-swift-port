//
//  NSURLConnectionDelegateQueue.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class iSubAppDelegate, MusicSingleton, DatabaseSingleton;

@interface NSURLConnectionDelegateQueue : NSObject
{
	iSubAppDelegate *appDelegate;
	MusicSingleton *musicControls;
	DatabaseSingleton *databaseControls;	
}


@end
