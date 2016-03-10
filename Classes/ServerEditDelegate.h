//
//  ServerEditDelegate.h
//  iSub
//
//  Created by Benjamin Baron on 3/9/16.
//  Copyright © 2016 Ben Baron. All rights reserved.
//

@class ISMSServer;
@protocol ServerEditDelegate <NSObject>
- (void)serverEdited:(ISMSServer *)server;
@end