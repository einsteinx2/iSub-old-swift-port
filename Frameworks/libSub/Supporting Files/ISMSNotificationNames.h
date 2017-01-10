//
//  ISMSNotificationNames.h
//  iSub
//
//  Created by Ben Baron on 11/19/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const ISMSNotification_SongPlaybackStarted;
extern NSString * const ISMSNotification_SongPlaybackPaused;
extern NSString * const ISMSNotification_SongPlaybackEnded;

extern NSString * const ISMSNotification_RepeatModeChanged;

extern NSString * const ISMSNotification_BassEffectPresetLoaded;

extern NSString * const ISMSNotification_CurrentPlaylistOrderChanged;
extern NSString * const ISMSNotification_CurrentPlaylistShuffleToggled;
extern NSString * const ISMSNotification_CurrentPlaylistIndexChanged;
extern NSString * const ISMSNotification_CurrentPlaylistSongsQueued;

extern NSString * const ISMSNotification_SongCachingEnabled;
extern NSString * const ISMSNotification_SongCachingDisabled;

extern NSString * const ISMSNotification_CacheQueueStarted;
extern NSString * const ISMSNotification_CacheQueueStopped;
extern NSString * const ISMSNotification_CacheQueueSongDownloaded;
extern NSString * const ISMSNotification_CacheQueueSongFailed;

extern NSString * const ISMSNotification_StreamHandlerSongDownloaded;
extern NSString * const ISMSNotification_StreamHandlerSongFailed;

extern NSString * const ISMSNotification_CacheSizeChecked;

extern NSString * const ISMSNotification_EnteringOfflineMode;
extern NSString * const ISMSNotification_EnteringOnlineMode;

extern NSString * const ISMSNotification_CachedSongDeleted;

extern NSString * const ISMSNotification_ReachabilityChanged;
