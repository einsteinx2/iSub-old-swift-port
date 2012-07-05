//
//  NSString-time.m
//  iSub
//
//  Created by Benjamin Baron on 10/30/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSString+time.h"

@implementation NSString (time)

+ (NSString *)formatTime:(double)seconds
{	
	if (seconds <= 0)
		return @"0:00";

	NSUInteger roundedSeconds = ceil(seconds);
	
	int mins = (int) roundedSeconds / 60;
	int secs = (int) roundedSeconds % 60;
	if (secs < 10)
		return [NSString stringWithFormat:@"%i:0%i", mins, secs];
	else
		return [NSString stringWithFormat:@"%i:%i", mins, secs];
}

// Return the time since the date provided, formatted in English
+ (NSString *)relativeTime:(NSDate *)date
{
	NSTimeInterval timeSinceDate = [[NSDate date] timeIntervalSinceDate:date];
	NSInteger time;
	
	if ([date isEqualToDate:[NSDate dateWithTimeIntervalSince1970:0]])
	{
		return @"never";
	}
	if (timeSinceDate <= 60)
	{
		return @"just now";
	}
	else if (timeSinceDate > 60 && timeSinceDate <= 3600)
	{
		time = (int)(timeSinceDate / 60);
		
		if (time == 1)
			return @"1 minute ago";
		else
			return [NSString stringWithFormat:@"%i minutes ago", time];
	}
	else if (timeSinceDate > 3600 && timeSinceDate <= 86400)
	{
		time = (int)(timeSinceDate / 3600);
		
		if (time == 1)
			return @"1 hour ago";
		else
			return [NSString stringWithFormat:@"%i hours ago", time];
	}	
	else if (timeSinceDate > 86400 && timeSinceDate <= 604800)
	{
		time = (int)(timeSinceDate / 86400);
		
		if (time == 1)
			return @"1 day ago";
		else
			return [NSString stringWithFormat:@"%i days ago", time];
	}
	else if (timeSinceDate > 604800 && timeSinceDate <= 2629743.83)
	{
		time = (int)(timeSinceDate / 604800);
		
		if (time == 1)
			return @"1 week ago";
		else
			return [NSString stringWithFormat:@"%i weeks ago", time];
	}
	else if (timeSinceDate > 2629743.83)
	{
		time = (int)(timeSinceDate / 2629743.83);
		
		if (time == 1)
			return @"1 month ago";
		else
			return [NSString stringWithFormat:@"%i months ago", time];
	}
	
	return @"";
}

@end
