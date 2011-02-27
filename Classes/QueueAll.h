//
//  QueueAll.h
//  iSub
//
//  Created by Ben Baron on 1/16/11.
//  Copyright 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

@class iSubAppDelegate, MusicControlsSingleton, DatabaseControlsSingleton, ViewObjectsSingleton, Artist;

@interface QueueAll : NSObject 
{
	iSubAppDelegate *appDelegate;
	MusicControlsSingleton *musicControls;
	DatabaseControlsSingleton *databaseControls;
	ViewObjectsSingleton *viewObjects;
	
	NSURLConnection *connection;
	NSMutableData *receivedData;
	
	BOOL isQueue;
	BOOL isShuffleButton;
	BOOL doShowPlayer;
	
	NSString *currentPlaylist;
	NSString *shufflePlaylist;
		
	Artist *myArtist;
	
	NSMutableArray *folderIds;
}

@property (nonatomic, retain) NSString *currentPlaylist;
@property (nonatomic, retain) NSString *shufflePlaylist;

@property (nonatomic, retain) Artist *myArtist;

@property (nonatomic, retain) NSMutableArray *folderIds;

- (void)loadData:(NSString *)folderId artist:(Artist *)theArtist;// isQueue:(BOOL)queue;

- (void)queueData:(NSString *)folderId artist:(Artist *)theArtist;
- (void)cacheData:(NSString *)folderId artist:(Artist *)theArtist;
- (void)playAllData:(NSString *)folderId artist:(Artist *)theArtist;
- (void)shuffleData:(NSString *)folderId artist:(Artist *)theArtist;

@end
