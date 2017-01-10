//
//  LibSubDefines.h
//  Sub
//
//  Created by Benjamin Baron on 11/24/12.
//  Copyright (c) 2012 Einstein Times Two Software. All rights reserved.
//

#ifndef Sub_LibSubDefines_h
#define Sub_LibSubDefines_h

#import "ISMSNotificationNames.h"

typedef NS_ENUM(NSInteger, ISMSBassVisualType)
{
    ISMSBassVisualType_none      = 0,
    ISMSBassVisualType_line      = 1,
    ISMSBassVisualType_skinnyBar = 2,
    ISMSBassVisualType_fatBar    = 3,
    ISMSBassVisualType_aphexFace = 4,
    ISMSBassVisualType_maxValue  = 5
};

#define ISMSLoadingTimeout 240.0
#define ISMSServerCheckTimeout 15.0

#define kFeaturePlaylistsId @"com.einsteinx2.isublite.playlistUnlock"
#define kFeatureCacheId @"com.einsteinx2.isublite.cacheUnlock"
#define kFeatureVideoId @"com.einsteinx2.isublite.videoUnlock"
#define kFeatureAllId @"com.einsteinx2.isublite.allUnlock"

#ifdef BETA
    #ifdef SILENT
        #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
    #else
        #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
    #endif
#else
    #define LOG_LEVEL_ISUB_DEFAULT static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#endif

#ifdef BETA
    #define LOG_LEVEL_ISUB_DEBUG static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#else
    #define LOG_LEVEL_ISUB_DEBUG static const DDLogLevel ddLogLevel = DDLogLevelVerbose;
#endif

#endif
