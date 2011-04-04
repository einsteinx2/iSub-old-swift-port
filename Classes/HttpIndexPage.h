//
//  HttpIndexPage.h
//  iSub
//
//  Created by Ben Baron on 3/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class DatabaseControlsSingleton;

@interface HttpIndexPage : NSObject 
{
	DatabaseControlsSingleton *databaseControls;
	
    NSString *documentsDirectory;
}

@property (nonatomic, retain) NSString *documentsDirectory;

@end
