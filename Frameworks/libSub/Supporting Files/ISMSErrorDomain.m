//
//  ISMSErrorDomain.m
//  Pods
//
//  Created by Benjamin Baron on 2/10/16.
//
//

#import "ISMSErrorDomain.h"

NSString * const ISMSErrorDomain                        = @"iSub Error Domain";

NSInteger const ISMSErrorCode_NotASubsonicServer		= 1;
NSString * const ISMSErrorDesc_NotASubsonicServer		= @"This is not a Subsonic server";

NSInteger const ISMSErrorCode_NotXML					= 2;
NSString * const ISMSErrorDesc_NotXML					= @"This is not XML data";

NSInteger const ISMSErrorCode_CouldNotCreateConnection	= 3;
NSString * const ISMSErrorDesc_CouldNotCreateConnection	= @"Could not create network connection";

NSInteger const ISMSErrorCode_CouldNotSendChatMessage	= 4;
NSString * const ISMSErrorDesc_CouldNotSendChatMessage	= @"Could not send chat message";

NSInteger const ISMSErrorCode_NoLyricsElement           = 5;
NSString * const ISMSErrorDesc_NoLyricsElement          = @"No lyrics XML element found";

NSInteger const ISMSErrorCode_NoLyricsFound             = 6;
NSString * const ISMSErrorDesc_NoLyricsFound            = @"No lyrics found for this song";

NSInteger const ISMSErrorCode_IncorrectCredentials		= 7;
NSString * const ISMSErrorDesc_IncorrectCredentials		= @"Incorrect username or password.";

NSInteger const ISMSErrorCode_CouldNotReachServer		= 8;
NSString * const ISMSErrorDesc_CouldNotReachServer		= @"Could not reach the server";

// TODO: Update this error message to better explain and to point to free alternatives
NSInteger const ISMSErrorCode_SubsonicTrialOver         = 9;
NSString * const ISMSErrorDesc_SubsonicTrialOver		= @"Subsonic API Trial Expired";