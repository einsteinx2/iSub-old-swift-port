//
//  NSURLConnectionDelegateQueue.h
//  iSub
//
//  Created by bbaron on 11/12/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class iSubAppDelegate, MusicControlsSingleton, DatabaseControlsSingleton;

@interface NSURLConnectionDelegateQueue : NSObject
{
	iSubAppDelegate *appDelegate;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;	
}


@end
