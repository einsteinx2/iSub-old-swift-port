//
//  SUSDirectoryLoader.h
//  iSub
//
//  Created by Ben Baron on 7/18/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>
#import "Loader.h"

@interface SUSDirectoryLoader : Loader 
{
    NSURLConnection *connection;
	NSMutableData *receivedData;
}

@end
