//
//  SUSCoverArtLoader.h
//  iSub
//
//  Created by Ben Baron on 11/1/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "SUSLoader.h"

@class DatabaseSingleton, ViewObjectsSingleton;
@interface SUSCoverArtLoader : SUSLoader
{
	DatabaseSingleton *databaseControls;
	ViewObjectsSingleton *viewObjects;
}

@property (nonatomic, copy) NSString *coverArtId;

@end
