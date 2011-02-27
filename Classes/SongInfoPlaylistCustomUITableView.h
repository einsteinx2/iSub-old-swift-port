//
//  CustomUITableView.h
//  iSub
//
//  Created by Ben Baron on 4/27/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class iSubAppDelegate;

@interface SongInfoPlaylistCustomUITableView : UITableView 
{
	NSDate *lastDeleteToggle;
}

@property (nonatomic, retain) NSDate *lastDeleteToggle;

@end
