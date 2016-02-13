//
//  ServerListViewController.h
//  iSub
//
//  Created by Ben Baron on 3/31/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"
#import "CustomUITableViewController.h"

@class SettingsTabViewController, HelpTabViewController, PMSLoginLoader;
@interface ServerListViewController : CustomUITableViewController <ISMSLoaderDelegate>

@end
