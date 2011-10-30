//
//  ServerCheckConnectionDelegate.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

@protocol ServerCheckDelegate <NSObject>
- (void)serverCheckFailed;
- (void)serverCheckPassed;
@end

@interface ServerCheckConnectionDelegate : NSObject

@property (nonatomic, assign) NSObject<ServerCheckDelegate> *delegate;
@property (nonatomic, retain) NSMutableData *receivedData;

- (id)initWithDelegate:(NSObject<ServerCheckDelegate> *)theDelegate;

@end
