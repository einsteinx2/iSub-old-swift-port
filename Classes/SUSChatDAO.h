//
//  SUSChatDAO.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "LoaderDelegate.h"
#import "LoaderManager.h"

@interface SUSChatDAO : NSObject <LoaderManager>

@property (nonatomic, retain) SUSChatLoader *loader;

- (void)sendChatMessage;

@end
