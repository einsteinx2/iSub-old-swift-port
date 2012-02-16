//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "SUSLoaderDelegate.h"
#import "SUSLoaderManager.h"

@class FMDatabase, Artist, Album, Song, SUSSubFolderLoader;

@interface SUSSubFolderDAO : NSObject <SUSLoaderDelegate, SUSLoaderManager>
{
    NSUInteger albumStartRow;
    NSUInteger songStartRow;
    NSUInteger albumsCount;
    NSUInteger songsCount;
}

@property (readonly) FMDatabase *db;

@property (assign) id<SUSLoaderDelegate> delegate;
@property (retain) SUSSubFolderLoader *loader;

@property (copy) NSString *myId;
@property (copy) Artist *myArtist;

@property (readonly) NSUInteger albumsCount;
@property (readonly) NSUInteger songsCount;
@property (readonly) NSUInteger totalCount;
@property (readonly) BOOL hasLoaded;
@property (readonly) NSUInteger folderLength;

@property (readonly) NSArray *sectionInfo;

- (id)initWithDelegate:(id <SUSLoaderDelegate>)theDelegate;
- (id)initWithDelegate:(id<SUSLoaderDelegate>)theDelegate andId:(NSString *)folderId andArtist:(Artist *)anArtist;

- (Album *)albumForTableViewRow:(NSUInteger)row;
- (Song *)songForTableViewRow:(NSUInteger)row;

- (void)playSongAtTableViewRow:(NSUInteger)row;

@end
