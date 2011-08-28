//
//  CustomUITableView.m
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import "SongInfoPlaylistCustomUITableView.h"
#import "ViewObjectsSingleton.h"

@interface NSObject (cell)
- (void)toggleDelete;
@end

@implementation SongInfoPlaylistCustomUITableView

@synthesize lastDeleteToggle;

- (id)initWithFrame:(CGRect)frame 
{
    if ((self = [super initWithFrame:frame])) 
	{
		self.lastDeleteToggle = [NSDate date];
    }
    return self;
}

- (id)initWithCoder:(NSCoder *)aDecoder
{
	if ((self = [super initWithCoder:aDecoder]))
	{
		self.lastDeleteToggle = [NSDate date];
	}
	return self;
}

#pragma mark Touch gestures interception

- (UIView *)hitTest:(CGPoint)point withEvent:(UIEvent *)event
{
	ViewObjectsSingleton *viewObjects = [ViewObjectsSingleton sharedInstance];
	
	if (viewObjects.isEditing)
	{
		if ((point.x < 40) && ([[NSDate date] timeIntervalSinceDate:lastDeleteToggle] > 0.25))
		{
			self.lastDeleteToggle = [NSDate date];
			//DLog(@"calling toggleDelete");
			NSIndexPath *indexPathAtHitPoint = [self indexPathForRowAtPoint:point];
			id cell = [self cellForRowAtIndexPath:indexPathAtHitPoint];
			[cell toggleDelete];
		}
	}

	return [super hitTest:point withEvent:event];
}



- (BOOL)touchesShouldCancelInContentView:(UIView *)view 
{
	return YES;
}


- (BOOL)touchesShouldBegin:(NSSet *)touches withEvent:(UIEvent *)event inContentView:(UIView *)view 
{
	return YES;
}


- (void)dealloc {
	[lastDeleteToggle release]; lastDeleteToggle = nil;
    [super dealloc];
}


@end
