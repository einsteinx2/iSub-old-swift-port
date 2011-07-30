//
//  DefaultSettings.h
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>


@interface DefaultSettings : NSObject 
{
	NSUserDefaults *savedDefaults;
	
	NSString *urlString;
	NSString *username;
	NSString *password;
}

@property (nonatomic, retain) NSString *urlString;
@property (nonatomic, retain) NSString *username;
@property (nonatomic, retain) NSString *password;

+ (DefaultSettings *)sharedInstance;

- (void)saveTopLevelIndexes:(NSArray *)indexes folders:(NSArray *)folders;
- (NSArray *)getTopLevelIndexes;
- (NSArray *)getTopLevelFolders;
- (NSDate *)getTopLevelFoldersReloadTime;

@end
