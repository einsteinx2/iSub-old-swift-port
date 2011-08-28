//
//  CustomUIAlertView.m
//  iSub
//
//  Created by Ben Baron on 2/27/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "CustomUIAlertView.h"
//#import "iSubAppDelegate.h"
#import "SavedSettings.h"

@implementation CustomUIAlertView

- (void)show
{
	//iSubAppDelegate *appDelegate = [iSubAppDelegate sharedInstance];
	
	//if (![[appDelegate.settingsDictionary objectForKey:@"disablePopupsSetting"] isEqualToString:@"YES"])
	if ([SavedSettings sharedInstance].isPopupsEnabled)
		[super show];
}

@end
