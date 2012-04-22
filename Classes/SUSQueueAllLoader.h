//
//  QueueAll.h
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//
#import "SUSLoader.h"

@class Artist;

@interface SUSQueueAllLoader : SUSLoader 
{
	BOOL isQueue;
	BOOL isShuffleButton;
	BOOL doShowPlayer;
	
	BOOL isCancelled;
}

@property (copy) NSString *currentPlaylist;
@property (copy) NSString *shufflePlaylist;

@property (strong) Artist *myArtist;

@property (strong) NSMutableArray *folderIds;

- (void)loadData:(NSString *)folderId artist:(Artist *)theArtist;// isQueue:(BOOL)queue;

- (void)queueData:(NSString *)folderId artist:(Artist *)theArtist;
- (void)cacheData:(NSString *)folderId artist:(Artist *)theArtist;
- (void)playAllData:(NSString *)folderId artist:(Artist *)theArtist;
- (void)shuffleData:(NSString *)folderId artist:(Artist *)theArtist;

@end
