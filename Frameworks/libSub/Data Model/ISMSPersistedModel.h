//
//  ISMSPersistedModel.h
//  libSub
//
//  Created by Benjamin Baron on 12/29/14.
//  Copyright (c) 2014 Einstein Times Two Software. All rights reserved.
//

#import "ISMSItem.h"

@protocol ISMSPersistedModel <ISMSItem>

- (nullable instancetype)initWithItemId:(NSInteger)itemId serverId:(NSInteger)serverId;

- (BOOL)insertModel;
- (BOOL)replaceModel;
- (BOOL)cacheModel;
- (BOOL)deleteModel;

- (void)reloadSubmodels;

@end
