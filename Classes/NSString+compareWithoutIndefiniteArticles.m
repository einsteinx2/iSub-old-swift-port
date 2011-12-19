//
//  NSString+compareWithoutIndefiniteArticles.m
//  iSub
//
//  Created by Ben Baron on 12/17/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+compareWithoutIndefiniteArticles.h"

@implementation NSString (compareWithoutIndefiniteArticles)

- (NSString *)stringWithoutIndefiniteArticle
{
	// Remove: The El La Los Las Le Les from beginning of string
	if ([self length] > 5)
	{
		NSString *artistPrefix = [[self substringToIndex:4] lowercaseString];
		if ([artistPrefix isEqualToString:@"the "] || [artistPrefix isEqualToString:@"los "] ||
			[artistPrefix isEqualToString:@"las "] || [artistPrefix isEqualToString:@"les "])
		{
			return [NSString stringWithFormat:@"%@, %@", [self substringFromIndex:4], [self substringToIndex:3]];
		}
	}
	else if ([self length] > 4)
	{
		NSString *artistPrefix = [[self substringToIndex:4] lowercaseString];
		if ([artistPrefix isEqualToString:@"el "] || [artistPrefix isEqualToString:@"la "] ||
			[artistPrefix isEqualToString:@"le "])
		{
			return [NSString stringWithFormat:@"%@, %@", [self substringFromIndex:3], [self substringToIndex:2]];
		}
	}
	
	// Does not contain an article
	return [[self copy] autorelease];
}

- (NSComparisonResult)compareWithoutIndefiniteArticles:(NSString *)otherString
{
	return [[self stringWithoutIndefiniteArticle] compare:[otherString stringWithoutIndefiniteArticle]];
}

- (NSComparisonResult)caseInsensitiveCompareWithoutIndefiniteArticles:(NSString *)otherString
{
	return [[self stringWithoutIndefiniteArticle] caseInsensitiveCompare:[otherString stringWithoutIndefiniteArticle]];
}

@end
