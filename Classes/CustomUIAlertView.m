//
//  CustomUIAlertView.m
//  iSub
//
//  Created by Ben Baron on 2/27/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CustomUIAlertView.h"
#import "SavedSettings.h"

@implementation CustomUIAlertView

- (void)show
{
	if ([SavedSettings sharedInstance].isPopupsEnabled)
		[super show];
}

@end
