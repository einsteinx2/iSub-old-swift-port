//
//  Imports.h
//  iSub
//
//  Created by Ben Baron on 5/8/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef iSub_Imports_h
#define iSub_Imports_h

typedef enum
{
    ISMSBassVisualType_none      = 0,
    ISMSBassVisualType_line      = 1,
    ISMSBassVisualType_skinnyBar = 2,
    ISMSBassVisualType_fatBar    = 3,
    ISMSBassVisualType_aphexFace = 4,
    ISMSBassVisualType_maxValue  = 5
} ISMSBassVisualType;

#import "EX2Kit.h"

#import "iSubAppDelegate.h"
#import "AudioEngine.h"
#import "SavedSettings.h"
#import "PlaylistSingleton.h"
#import "CacheSingleton.h"
#import "DatabaseSingleton.h"
#import "MusicSingleton.h"
#import "SocialSingleton.h"
#import "ViewObjectsSingleton.h"
#import "JukeboxSingleton.h"

#import "ISMSNotificationNames.h"
#import "ISMSErrorDomain.h"
#import "SUSErrorDomain.h"

#import "FlurryAnalytics.h"

#define ISMSLoadingTimeout 240.0
#define ISMSJukeboxTimeout 60.0
#define ISMSServerCheckTimeout 15.0

// 3G restrictions
#define IS_3G_UNRESTRICTED NO   // 3G is restricted (safe for App Store)
//#define IS_3G_UNRESTRICTED YES  // 3G is NOT restricted (NOT safe for App Store)

#define ISMSiPadBackgroundColor [UIColor colorWithPatternImage:[UIImage imageNamed:@"underPageBackground.png"]]
#define ISMSiPadCornerRadius 5.



#endif
