//
//  ISMSContentType.m
//  libSub
//
//  Created by Benjamin Baron on 2/2/16.
//  Copyright © 2016 Einstein Times Two Software. All rights reserved.
//

#import "ISMSContentType.h"
#import "Imports.h"

@implementation ISMSContentType

- (instancetype)initWithContentTypeId:(NSInteger)contentTypeId
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            NSString *query = @"SELECT * FROM contentTypes WHERE contentTypeId = ?";
            FMResultSet *r = [db executeQuery:query, @(contentTypeId)];
            if ([r next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:r];
            }
            [r close];
        }];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (instancetype)initWithMimeType:(NSString *)mimeType
{
    if (self = [super init])
    {
        __block BOOL foundRecord = NO;
        
        [databaseS.songModelReadDbPool inDatabase:^(FMDatabase *db) {
            NSString *query = @"SELECT * FROM contentTypes WHERE mimeType = ?";
            FMResultSet *r = [db executeQuery:query, mimeType];
            if ([r next])
            {
                foundRecord = YES;
                [self _assignPropertiesFromResultSet:r];
            }
            [r close];
        }];
        
        return foundRecord ? self : nil;
    }
    
    return nil;
}

- (void)_assignPropertiesFromResultSet:(FMResultSet *)resultSet
{
    _contentTypeId = [resultSet objectForColumnIndex:0];
    _mimeType = [resultSet objectForColumnIndex:1];
    _extension = [resultSet objectForColumnIndex:2];
    _basicType = [resultSet intForColumnIndex:3];
}

@end
