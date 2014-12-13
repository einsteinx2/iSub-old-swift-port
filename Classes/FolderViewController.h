//
//  FolderViewController.h
//  iSub
//
//  Created by Ben Baron on 2/28/10.
//  Copyright 2010 Ben Baron. All rights reserved.
//

@class ISMSArtist, ISMSAlbum;

@interface FolderViewController : CustomUITableViewController

- (FolderViewController *)initWithArtist:(ISMSArtist *)anArtist orAlbum:(ISMSAlbum *)anAlbum;

@end
