//
//  ISMSErrorCodes.h
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import <Foundation/Foundation.h>

extern NSString * const ISMSErrorDomain;

extern NSInteger const ISMSErrorCode_NotASubsonicServer;
extern NSString * const ISMSErrorDesc_NotASubsonicServer;

extern NSInteger const ISMSErrorCode_NotXML;
extern NSString * const ISMSErrorDesc_NotXML;

extern NSInteger const ISMSErrorCode_CouldNotCreateConnection;
extern NSString * const ISMSErrorDesc_CouldNotCreateConnection;

extern NSInteger const ISMSErrorCode_CouldNotSendChatMessage;
extern NSString * const ISMSErrorDesc_CouldNotSendChatMessage;

extern NSInteger const ISMSErrorCode_NoLyricsElement;
extern NSString * const ISMSErrorDesc_NoLyricsElement;

extern NSInteger const ISMSErrorCode_NoLyricsFound;
extern NSString * const ISMSErrorDesc_NoLyricsFound;

extern NSInteger const ISMSErrorCode_IncorrectCredentials;
extern NSString * const ISMSErrorDesc_IncorrectCredentials;

extern NSInteger const ISMSErrorCode_CouldNotReachServer;
extern NSString * const ISMSErrorDesc_CouldNotReachServer;

extern NSInteger const ISMSErrorCode_SubsonicTrialOver;
extern NSString * const ISMSErrorDesc_SubsonicTrialOver;
