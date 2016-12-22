//
//  ISMSPlaylistsLoader.h
//  iSub
//
//  Created by Benjamin Baron on 11/6/11.
//  Copyright (c) 2015 Ben Baron. All rights reserved.
//

#import "ISMSLoader.h"
#import "ISMSAbstractItemLoader.h"

@class ISMSPlaylist;
@interface ISMSPlaylistsLoader : ISMSAbstractItemLoader <ISMSItemLoader>

@property (nullable, readonly) NSArray<id<ISMSItem>> *items;
@property (nullable, strong) NSArray<ISMSPlaylist*> *playlists;

@end
