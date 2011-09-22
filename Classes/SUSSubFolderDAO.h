//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER
#import "Loader.h"

@class FMDatabase, Album;

@interface SUSSubFolderDAO : Loader
{
	FMDatabase *db;
	
	NSURLConnection *connection;
	NSMutableData *receivedData;
}


@end
