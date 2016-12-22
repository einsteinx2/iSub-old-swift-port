//
//  ISMSAbstractItemLoader.m
//  libSub
//
//  Created by Benjamin Baron on 1/31/16.
//  Copyright © 2016 Einstein Times Two Software. All rights reserved.
//

#import "ISMSAbstractItemLoader.h"
#import "LibSub.h"

@implementation ISMSAbstractItemLoader

- (NSArray<id<ISMSItem>> *)items
{
    return nil;
}

- (id)associatedObject
{
    return nil;
}

- (void)persistModels
{
    
}

- (BOOL)loadModelsFromCache
{
    return NO;
}

@end
