//
//  HttpIndexPage.h
//  iSub
//
//  Created by Ben Baron on 3/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

//#import <Foundation/Foundation.h>  // REMOVED THIS TO STOP XCODE SYNTAX HIGHLIGHT PROBLEM, THIS IS INCLUDED IN THE PROJECT HEADER

@class DatabaseSingleton;

@interface HttpIndexPage : NSObject 
{
	DatabaseSingleton *databaseControls;
	
    NSString *documentsDirectory;
}

@property (nonatomic, retain) NSString *documentsDirectory;

@end
