//
//  HttpIndexPage.h
//  iSub
//
//  Created by Ben Baron on 3/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//



@class DatabaseSingleton;

@interface HttpIndexPage : NSObject 
{
	DatabaseSingleton *databaseControls;
	
    NSString *documentsDirectory;
}

@property (nonatomic, retain) NSString *documentsDirectory;

@end
