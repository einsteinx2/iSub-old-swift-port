//
//  FMDatabase+Synchronized.h
//  iSub
//
//  Created by Ben Baron on 12/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "FMDatabase.h"
#import "FMDatabaseAdditions.h"

@interface FMDatabase (Synchronized)

- (FMResultSet *)synchronizedQuery:(NSString*)sql, ...;
- (BOOL)synchronizedUpdate:(NSString*)sql, ...;

- (int)synchronizedIntForQuery:(NSString*)objs, ...;
- (long)synchronizedLongForQuery:(NSString*)objs, ...; 
- (BOOL)synchronizedBoolForQuery:(NSString*)objs, ...;
- (double)synchronizedDoubleForQuery:(NSString*)objs, ...;
- (NSString*)synchronizedStringForQuery:(NSString*)objs, ...; 
- (NSData*)synchronizedDataForQuery:(NSString*)objs, ...;
- (NSDate*)synchronizedDateForQuery:(NSString*)objs, ...;

@end
