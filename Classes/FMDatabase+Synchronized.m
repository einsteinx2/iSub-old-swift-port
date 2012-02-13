//
//  FMDatabase+Synchronized.m
//  iSub
//
//  Created by Ben Baron on 12/14/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "FMDatabase+Synchronized.h"

@implementation FMDatabase (Synchronized)

- (FMResultSet *)synchronizedExecuteQuery:(NSString*)sql, ...
{
	@synchronized(self)
	{
		va_list args;
		va_start(args, sql);
		
		id result = [self executeQuery:sql withArgumentsInArray:nil orVAList:args];
		
		va_end(args);
		return result;
	}
}

- (BOOL)synchronizedExecuteUpdate:(NSString*)sql, ...
{
	@synchronized(self)
	{
		va_list args;
		va_start(args, sql);
		
		BOOL result = [self executeUpdate:sql error:nil withArgumentsInArray:nil orVAList:args];
		
		va_end(args);
		return result;
	}
}

- (NSString*)synchronizedStringForQuery:(NSString*)query, ... 
{
	@synchronized(self)
	{
		RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSString *, stringForColumnIndex);
	}
}

- (int)synchronizedIntForQuery:(NSString*)query, ... 
{
	@synchronized(self)
	{
		RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(int, intForColumnIndex);
	}
}

- (long)synchronizedLongForQuery:(NSString*)query, ... 
{
	@synchronized(self)
	{
		RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(long, longForColumnIndex);
	}
}

- (BOOL)synchronizedBoolForQuery:(NSString*)query, ... 
{
	@synchronized(self)
	{
		RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(BOOL, boolForColumnIndex);
	}
}

- (double)synchronizedDoubleForQuery:(NSString*)query, ... 
{
	@synchronized(self)
	{
		RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(double, doubleForColumnIndex);
	}
}

- (NSData*)synchronizedDataForQuery:(NSString*)query, ... 
{
	@synchronized(self)
	{
		RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSData *, dataForColumnIndex);
	}
}

- (NSDate*)synchronizedDateForQuery:(NSString*)query, ... 
{
	@synchronized(self)
	{
		RETURN_RESULT_FOR_QUERY_WITH_SELECTOR(NSDate *, dateForColumnIndex);
	}
}

@end


