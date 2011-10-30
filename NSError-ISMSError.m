//
//  ISMSError.m
//  iSub
//
//  Created by Benjamin Baron on 10/29/11.
//  Copyright (c) 2011 Ben Baron. All rights reserved.
//

#import "NSError-ISMSError.h"

@implementation NSError (ISMSError)

+ (NSError *)errorWithISMSCode:(NSInteger)code
{
    NSString *description = nil;
    
    switch (code) 
    {
        case ISMSErrorCode_NotASubsonicServer:
            description = ISMSErrorDesc_NotASubsonicServer;
            break;
        case ISMSErrorCode_NotXML:
            description = ISMSErrorDesc_NotXML;
            break;
        case ISMSErrorCode_CouldntCreateConnection:
            description = ISMSErrorDesc_CouldntCreateConnection;
        default:
            break;
    }
    
    NSDictionary *dict = [NSDictionary dictionaryWithObject:description forKey:NSLocalizedDescriptionKey];
    
    return [NSError errorWithDomain:ISMSErrorDomain code:code userInfo:dict];
}

@end
