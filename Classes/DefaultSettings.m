//
//  DefaultSettings.m
//  iSub
//
//  Created by Ben Baron on 7/17/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "DefaultSettings.h"


@implementation DefaultSettings

@synthesize urlString, username, password;

- (void)saveTopLevelIndexes:(NSArray *)indexes folders:(NSArray *)folders
{
	[savedDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:indexes] forKey:[NSString stringWithFormat:@"%@topLevelIndexes", urlString]];
	[savedDefaults setObject:[NSKeyedArchiver archivedDataWithRootObject:folders] forKey:[NSString stringWithFormat:@"%@topLevelFolders", urlString]];
	[savedDefaults setObject:[NSDate date] forKey:[NSString stringWithFormat:@"%@topLevelFoldersReloadTime", urlString]];
	[savedDefaults synchronize];
}

- (NSArray *)getTopLevelIndexes
{
	NSArray *indexes = nil;
	
	NSData *archived = [savedDefaults objectForKey:[NSString stringWithFormat:@"%@topLevelIndexes", urlString]];
	if (archived != nil)
	{
		indexes = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
	}
	
	return indexes;
}

- (NSArray *)getTopLevelFolders
{
	NSArray *folders = nil;
	
	NSData *archived = [savedDefaults objectForKey:[NSString stringWithFormat:@"%@topLevelFolders", urlString]];
	if (archived != nil)
	{
		folders = [NSKeyedUnarchiver unarchiveObjectWithData:archived];
	}
	
	return folders;
}

- (NSDate *)getTopLevelFoldersReloadTime
{
	return [savedDefaults objectForKey:[NSString stringWithFormat:@"%@topLevelFoldersReloadTime", urlString]];
}

#pragma mark -
#pragma mark Singleton methods

static DefaultSettings *sharedInstance = nil;

+ (DefaultSettings *)sharedInstance
{
    @synchronized(self)
    {
		if (sharedInstance == nil)
			[[self alloc] init];
    }
    return sharedInstance;
}

+ (id)allocWithZone:(NSZone *)zone 
{
    @synchronized(self) 
	{
        if (sharedInstance == nil) 
		{
            sharedInstance = [super allocWithZone:zone];
            return sharedInstance;  // assignment and return on first allocation
        }
    }
    return nil; // on subsequent allocation attempts return nil
}

-(id)init 
{
	if ((self = [super init]))
	{
		sharedInstance = self;
		savedDefaults = [NSUserDefaults standardUserDefaults];
	}
	
	return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return self;
}

- (id)retain 
{
    return self;
}

- (unsigned)retainCount 
{
    return UINT_MAX;  // denotes an object that cannot be released
}

- (void)release 
{
    //do nothing
}

- (id)autorelease 
{
    return self;
}

@end
