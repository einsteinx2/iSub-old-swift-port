//
//  JukeboxConnectionDelegate.h
//  iSub
//
//  Created by Ben Baron on 12/14/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class MusicControlsSingleton;

@interface JukeboxConnectionDelegate : NSObject 
{
	NSMutableData *receivedData;
	
	BOOL isGetInfo;
	
	MusicControlsSingleton *musicControls;
}

@property (nonatomic, retain) NSMutableData *receivedData;
@property BOOL isGetInfo;

@end
