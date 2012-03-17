//
//  Macros.h
//  iSub
//
//  Created by Ben Baron on 3/10/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef iSub_Macros_h
#define iSub_Macros_h

// 240.0 is the minimum URL connection timeout enforced by CFNetwork
// Unless an HTTP Post body is created then it may default to 74.0
// unless you reset the timeout after setting up the post body
#define ISMSLoadingTimeout 240.0
#define ISMSJukeboxTimeout 60.0
#define ISMSServerCheckTimeout 15.0

#define BytesToKB(value) (value * 1024)
#define BytesToMB(value) (BytesToKB(value) * 1024)
#define BytesToGB(value) (BytesToMB(value) * 1024)

// iPad detection
#ifdef UI_USER_INTERFACE_IDIOM//()
#define IS_IPAD() (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#else
#define IS_IPAD() (false)
#endif

// 3G restrictions
#define IS_3G_UNRESTRICTED NO   // 3G is restricted (safe for App Store)
//#define IS_3G_UNRESTRICTED YES  // 3G is NOT restricted (NOT safe for App Store)

// Lite version build switch
#ifdef LITE
#define IS_LITE() (true)  // ENABLE  Lite version
#else
#define IS_LITE() (false) // DISABLE Lite version
#endif

// Beta version build switch
#ifdef BETA
#define IS_BETA() (true)
#else
#define IS_BETA() (false)
#endif

// Debug version build switch (activated only on debug builds)
#ifdef DEBUG
#define IS_DEBUG() (true)
#else
#define IS_DEBUG() (false)
#endif

// Adhoc version build switch (activated only on adhoc)
#ifdef ADHOC
#define IS_ADHOC() (true)
#else
#define IS_ADHOC() (false)
#endif

// Release version build switch
#ifdef RELEASE
#define IS_RELEASE() (true)
#else
#define IS_RELEASE() (false)
#endif

// Screen scale detection
#define SCREEN_SCALE() ([[UIScreen mainScreen] respondsToSelector:@selector(scale)] ? [[UIScreen mainScreen] scale] : 1.0f)

// Multitasking support check
#define IS_MULTITASKING() ([[UIDevice currentDevice] respondsToSelector:@selector(multitaskingSupported)] ? [UIDevice currentDevice].multitaskingSupported : false)

// DLog is almost a drop-in replacement for NSLog
// DLog();
// DLog(@"here");
// DLog(@"value: %d", x);
// Unfortunately this doesn't work DLog(aStringVariable); you have to do this instead DLog(@"%@", aStringVariable);
#ifdef DEBUG
#define DLog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)
#else
#define DLog(...)
#endif

// ALog always displays output regardless of the DEBUG setting
#define ALog(fmt, ...) NSLog((@"%s [Line %d] " fmt), __PRETTY_FUNCTION__, __LINE__, ##__VA_ARGS__)

#define n2N(value) (value ? value : [NSNull null])

//static id n2N(id value) { return value ? value : [NSNull null]; }

#define NSStringFromBOOL(value) (value ? @"YES" : @"NO")

#define BytesForSecondsAtBitrate(seconds, bitrate) ((bitrate / 8) * 1024 * seconds)

#define ISMSiPadBackgroundColor [UIColor colorWithPatternImage:[UIImage imageNamed:@"underPageBackground.png"]]
#define ISMSiPadCornerRadius 5.

typedef enum
{
	ISMSBassVisualType_none		 = 0,
	ISMSBassVisualType_line		 = 1,
	ISMSBassVisualType_skinnyBar = 2,
	ISMSBassVisualType_fatBar	 = 3,
	ISMSBassVisualType_aphexFace = 4
} ISMSBassVisualType;

#endif
