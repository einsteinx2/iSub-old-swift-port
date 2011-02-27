//
//  GenresViewController.h
//  iSub
//
//  Created by Ben Baron on 5/26/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

#import <UIKit/UIKit.h>

@class iSubAppDelegate, ViewObjectsSingleton, MusicControlsSingleton, DatabaseControlsSingleton;

@interface GenresViewController : UITableViewController 
{
	iSubAppDelegate *appDelegate;
	ViewObjectsSingleton *viewObjects;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	
	BOOL isNoGenresScreenShowing;
	UIImageView *noGenresScreen;
}

@end
