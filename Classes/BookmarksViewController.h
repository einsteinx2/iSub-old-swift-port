//
//  BookmarksViewController.h
//  iSub
//
//  Created by Ben Baron on 5/10/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@interface BookmarksViewController : UITableViewController
{
	
	BOOL isNoBookmarksScreenShowing;
	UIImageView *noBookmarksScreen;
	
	UIView *headerView;
	UILabel *bookmarkCountLabel;
	UIButton *deleteBookmarksButton;
	UILabel *deleteBookmarksLabel;
	UILabel *spacerLabel;
	UILabel *editBookmarksLabel;
	UIButton *editBookmarksButton;
}

@end
