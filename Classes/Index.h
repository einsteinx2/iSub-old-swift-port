//
//  Index.h
//  iSub
//
//  Created by Ben Baron on 2/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//



@interface Index : NSObject 
{
	NSString *name;
	NSUInteger position;
	NSUInteger count;
}

@property (retain) NSString *name;
@property NSUInteger position;
@property NSUInteger count;

@end
