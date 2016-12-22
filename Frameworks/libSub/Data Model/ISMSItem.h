//
//  ISMSItem.h
//  iSub
//
//  Created by Ben Baron on 9/9/12.
//  Copyright (c) 2015 Ben Baron. All rights reserved.
//

@protocol ISMSItem <NSObject>

@property (nullable, strong, readonly) NSNumber *itemId;
@property (nullable, copy, readonly) NSString *itemName;

@optional @property (nullable, strong, readonly) NSNumber *serverId;

@end