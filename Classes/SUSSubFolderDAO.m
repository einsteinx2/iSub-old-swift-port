//
//  SUSSubFolderDAO.m
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSSubFolderDAO.h"
#import "DatabaseSingleton.h"
#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@implementation SUSSubFolderDAO

#pragma mark - Lifecycle

- (void)setup
{
}

- (id)init
{
    self = [super init];
    if (self) 
	{
		[self setup];
    }
    
    return self;
}

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate
{
	self = [super initWithDelegate:theDelegate];
    if (self) 
	{
		[self setup];
    }
    
    return self;
}

- (void)dealloc
{
	[super dealloc];
}

- (FMDatabase *)db
{
    return [[DatabaseSingleton sharedInstance] albumListCacheDb]; 
}

@end
