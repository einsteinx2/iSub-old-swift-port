//
//  SubsonicServerEditViewController.h
//  iSub
//
//  Created by Ben Baron on 3/3/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ServerEditDelegate.h"

@class ServerTypeViewController, Server;
@interface SubsonicServerEditViewController : UIViewController

@property (nullable, nonatomic, weak) id<ServerEditDelegate> delegate;

@property (nullable, nonatomic, strong) Server *server;
@property (nullable, nonatomic, copy) NSString *redirectUrl;

- (nonnull instancetype)initWithServer:(nullable Server *)server;

@end
