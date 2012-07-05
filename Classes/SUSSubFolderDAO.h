//
//  SUSSubFolderDAO.h
//  iSub
//
//  Created by Ben Baron on 8/25/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import "ISMSLoaderDelegate.h"
#import "ISMSLoaderManager.h"

@class FMDatabase, Artist, Album, Song, ISMSSubFolderLoader;

@interface SUSSubFolderDAO : NSObject <ISMSLoaderDelegate, ISMSLoaderManager>

@property NSUInteger albumStartRow;
@property NSUInteger songStartRow;
@property NSUInteger albumsCount;
@property NSUInteger songsCount;

@property (unsafe_unretained) id<ISMSLoaderDelegate> delegate;
@property (strong) ISMSSubFolderLoader *loader;

@property (copy) NSString *myId;
@property (copy) Artist *myArtist;

@property (readonly) NSUInteger totalCount;
@property (readonly) BOOL hasLoaded;
@property (readonly) NSUInteger folderLength;

- (NSArray *)sectionInfo;

- (id)initWithDelegate:(id <ISMSLoaderDelegate>)theDelegate;
- (id)initWithDelegate:(id<ISMSLoaderDelegate>)theDelegate andId:(NSString *)folderId andArtist:(Artist *)anArtist;

- (Album *)albumForTableViewRow:(NSUInteger)row;
- (Song *)songForTableViewRow:(NSUInteger)row;

- (void)playSongAtTableViewRow:(NSUInteger)row;

@end
