//
//  SUSIndexesLoader.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "Loader.h"
#import "LoaderDelegate.h"

@interface SUSIndexesLoader : Loader
{
	NSURLConnection *connection;
	NSMutableData *receivedData;
	
	NSString *folderId;
}

@property (nonatomic, retain) NSString *folderId;

@end
