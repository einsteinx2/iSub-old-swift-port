//
//  EX2Macros.h
//  EX2Kit
//
//  Created by Ben Baron on 3/10/12.
//  Copyright (c) 2012 Ben Baron. All rights reserved.
//

#ifndef EX2Kit_Macros_h
#define EX2Kit_Macros_h

#define BytesFromKB(value) (value * 1000)
#define BytesFromMB(value) (BytesFromKB(value) * 1000)
#define BytesFromGB(value) (BytesFromMB(value) * 1000)

#define BytesFromKiB(value) (value * 1024)
#define BytesFromMiB(value) (BytesFromKiB(value) * 1024)
#define BytesFromGiB(value) (BytesFromMiB(value) * 1024)

// iPad detection
#ifdef UI_USER_INTERFACE_IDIOM//()
#define IS_IPAD() (UI_USER_INTERFACE_IDIOM() == UIUserInterfaceIdiomPad)
#else
#define IS_IPAD() (false)
#endif

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
#define N2n(value) (value == [NSNull null] ? nil : value)

//static id n2N(id value) { return value ? value : [NSNull null]; }

#define NSStringFromBOOL(value) (value ? @"YES" : @"NO")

#define BytesForSecondsAtBitrate(seconds, bitrate) ((bitrate / 8) * 1024 * seconds)

#define SYSTEM_VERSION_EQUAL_TO(v)                  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedSame)
#define SYSTEM_VERSION_GREATER_THAN(v)              ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedDescending)
#define SYSTEM_VERSION_GREATER_THAN_OR_EQUAL_TO(v)  ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN(v)                 ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] == NSOrderedAscending)
#define SYSTEM_VERSION_LESS_THAN_OR_EQUAL_TO(v)     ([[[UIDevice currentDevice] systemVersion] compare:v options:NSNumericSearch] != NSOrderedDescending)


#endif
