//
//  BassUserInfo.m
//  iSub
//
//  Created by Ben Baron on 1/17/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#import "BassUserInfo.h"
#import "Song.h"

@implementation BassUserInfo
@synthesize mySong, myFileHandle;

- (id)init
{
	if ((self = [super init]))
	{
		mySong = nil;
		myFileHandle = NULL;
	}
	return self;
}

- (void)dealloc
{
	DLog(@"BassUserInfo dealloc called!!");
	[mySong release]; mySong = nil;
	myFileHandle = NULL;
	[super dealloc];
}
@end
